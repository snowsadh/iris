/// Real HTTP authorization checks. Passwords exist only in memory; temporary users are removed afterward.
Class AllfedoWebScenario Extends %RegisteredObject
{
ClassMethod Prepare(credentialsJSON As %String, redirectOnly As %Boolean = 0) As %String
{
    Set credentials=##class(Allfedo.Rescue).Parse(credentialsJSON)
    Do ##class(AllfedoScenario).Setup(.ids), ##class(AllfedoScenario).Setup(.other)
    Set iterator=credentials.%GetIterator()
    While iterator.%GetNext(.kind,.account) {
        Do ##class(Allfedo.Rescue).Require($Extract(account.username,1,17)="allfedo-web-test-","Temporary test users need the explicit test prefix.")
        If kind'="nonmember" {
            Set id=$Select(kind="other":other.coordinator,kind="inactive":ids."second_kitchen",1:ids.%Get(kind))
            Set actor=##class(Allfedo.Rescue).Actor(id), actor.UserName=account.username
            If kind="inactive" Set actor.Active=0
            Do ##class(Allfedo.Rescue).Save(actor)
        }
        Do ..CreateUser(account.username,account.password)
    }
    Set plan=##class(AllfedoScenario).Plan(ids.coordinator,ids.offer,ids.need,"20")
    Set held=##class(AllfedoScenario).Run(ids.coordinator,"http-hold-one","apply_plan",plan)
    Do ##class(Allfedo.Rescue).Require(held.ok,"The first HTTP fixture invitation failed.")
    Set ids.allocation=held."allocation_ids".%Get(0)
    Set result=##class(AllfedoScenario).Run(ids.recipient,"http-accept-one","accept",{"allocation_id":(ids.allocation),"revision":1,"quantity":"20","context_key":(##class(AllfedoScenario).ContextKey(ids.allocation))})
    Do ##class(Allfedo.Rescue).Require(result.ok,"The HTTP fixture acceptance failed.")
    Set result=##class(AllfedoScenario).Run(ids.coordinator,"http-assign-one","assign_collector",{"allocation_id":(ids.allocation),"revision":2,"collector_actor_id":(ids.collector)})
    Do ##class(Allfedo.Rescue).Require(result.ok,"The HTTP fixture assignment failed.")
    Set ids."foreign_offer"=other.offer
    If redirectOnly Quit ids.%ToJSON()
    Set plan=##class(AllfedoScenario).Plan(ids.coordinator,ids.offer,ids."second_need","15")
    Set held=##class(AllfedoScenario).Run(ids.coordinator,"http-hold-two","apply_plan",plan)
    Do ##class(Allfedo.Rescue).Require(held.ok,"The second HTTP fixture invitation failed.")
    Set ids."other_allocation"=held."allocation_ids".%Get(0)
    // A clearly labeled saved-read fixture. No model/provider execution is claimed or required.
    Set snapshot=##class(Allfedo.Rescue).Snapshot(ids.coordinator,ids.offer)
    Set proposal=##class(AllfedoScenario).Plan(ids.coordinator,ids.offer,ids.need,"5")
    Set run=##class(Allfedo.Record.AgentRun).%New()
    Set run.NetworkId=ids.network, run.ActorId=ids.coordinator, run.OfferId=ids.offer, run.RequestId="http-saved-plan-fixture"
    Set run.StartedAt=##class(Allfedo.Policy).Now(), run.FinishedAt=run.StartedAt, run.Model="http-test-fixture-no-provider"
    Set run.SnapshotJSON=snapshot.%ToJSON(), run.ProposalJSON=proposal.%ToJSON(), run.Outcome="proposed", run.ToolAuditJSON="[]"
    Do ##class(Allfedo.Rescue).Save(run)
    Set ids."saved_plan"=""_run.%Id()
    Quit ids.%ToJSON()
}

ClassMethod CreateUser(username As %String, password As %String)
{
    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    If ##class(Security.Users).Exists(username) Throw ##class(%Exception.General).%New("The generated test account already exists.")
    Set status=##class(Security.Users).Create(username,"Allfedo_Partner",password,"Temporary Allfedo HTTP test","ALLFEDO","","",0,1,"Allfedo HTTP test owner: "_username)
    If $SYSTEM.Status.IsError(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
}

ClassMethod RemoveUsers(credentialsJSON As %String)
{
    Set credentials=##class(Allfedo.Rescue).Parse(credentialsJSON), iterator=credentials.%GetIterator()
    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    While iterator.%GetNext(.kind,.account) {
        If $Extract(account.username,1,17)="allfedo-web-test-",##class(Security.Users).Exists(account.username,.testUser) {
            If testUser.Comment=("Allfedo HTTP test owner: "_account.username) {
                Set status=##class(Security.Users).Delete(account.username)
                If $SYSTEM.Status.IsError(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
            }
        }
    }
}

/// A collision fixture belongs to this check, but deliberately lacks the cleanup owner marker.
ClassMethod CheckCleanupCollision(username As %String, password As %String) As %Boolean
{
    New $NAMESPACE
    Set fixtureNamespace=$NAMESPACE,$NAMESPACE="%SYS",collisionMarker="Allfedo foreign-account fixture: "_username
    If ($Extract(username,1,17)'="allfedo-web-test-")||##class(Security.Users).Exists(username) Throw ##class(%Exception.General).%New("Unsafe cleanup collision fixture.")
    Set status=##class(Security.Users).Create(username,"Allfedo_Partner",password,"Cleanup collision fixture","ALLFEDO","","",0,1,collisionMarker)
    If $SYSTEM.Status.IsError(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
    Set $NAMESPACE=fixtureNamespace
    Try {
        Set refused=0
        Try { Do ..CreateUser(username,password) } Catch collision { Set refused=1 }
        If 'refused Throw ##class(%Exception.General).%New("The existing account was not refused.")
        Set collisionInput={"collision":{"username":(username)}}
        Do ..RemoveUsers(collisionInput.%ToJSON())
        Set $NAMESPACE="%SYS"
        If '##class(Security.Users).Exists(username,.collisionUser) Throw ##class(%Exception.General).%New("Cleanup deleted an unrelated account.")
        If collisionUser.Comment'=collisionMarker Throw ##class(%Exception.General).%New("The unrelated account was changed.")
    } Catch error {
        Set $NAMESPACE="%SYS"
        If ##class(Security.Users).Exists(username,.collisionUser),collisionUser.Comment=collisionMarker Do ##class(Security.Users).Delete(username)
        Throw error
    }
    Set status=##class(Security.Users).Delete(username)
    If $SYSTEM.Status.IsError(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
    Quit 1
}

ClassMethod Run(baseURL As %String = "http://127.0.0.1:52773/allfedo/api", redirectOnly As %Boolean = 0) As %String [ Language = python ]
{
    import base64
    from datetime import datetime, timedelta, timezone
    import http.cookiejar
    from html.parser import HTMLParser
    import iris
    import json
    import secrets
    import urllib.error
    import urllib.request
    import urllib.parse
    import uuid

    suffix = uuid.uuid4().hex[:12]
    accounts = {role: {"username": "allfedo-web-test-" + suffix + "-" + role,
                       "password": secrets.token_urlsafe(32)}
                for role in ("coordinator", "kitchen", "recipient", "second_recipient", "collector", "other", "nonmember", "inactive")}
    credentials = json.dumps(accounts)
    checks = []

    def require(condition, message):
        if not condition:
            raise RuntimeError(message)
        checks.append(message)

    def request(path, role=None, command=None, headers=None, opener=None):
        selected = {"Accept": "application/json"}
        if role:
            account = accounts[role]
            selected["Authorization"] = "Basic " + base64.b64encode((account["username"] + ":" + account["password"]).encode()).decode()
        data = None
        if command is not None:
            data = json.dumps(command, ensure_ascii=False).encode("utf-8")
            selected.update({"Content-Type": "application/json", "X-Allfedo-Request": "1"})
        selected.update(headers or {})
        call = urllib.request.Request(baseURL + path, data=data, headers=selected)
        try:
            response = (opener.open if opener else urllib.request.urlopen)(call, timeout=30)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            content = response.read()
            try:
                body = json.loads(content)
            except (ValueError, UnicodeError):
                body = {}
            return response.status, body

    def send(role, action, payload):
        return request("/commands", role, {"request_id": "http-" + uuid.uuid4().hex, "action": action, "payload": payload})

    def instant():
        return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")

    fixture = None
    try:
        require(iris.cls("AllfedoWebScenario").CheckCleanupCollision("allfedo-web-test-" + suffix + "-collision", secrets.token_urlsafe(32) + "Aa1!"), "Failed setup cannot delete a colliding account without its exact test ownership marker")
        fixture = json.loads(iris.cls("AllfedoWebScenario").Prepare(credentials, redirectOnly))
        if redirectOnly:
            parent_path = "/allocations/" + str(fixture["allocation"])
            status, body = request(parent_path, "collector")
            parent = body["record"]
            pickup_at = (datetime.now(timezone.utc) + timedelta(minutes=1)).isoformat()
            arrival_by = (datetime.now(timezone.utc) + timedelta(minutes=20)).isoformat()
            status, result = send("collector", "confirm_transport", {"allocation_id": parent["id"], "revision": parent["revision"], "pickup_at": pickup_at, "arrival_by": arrival_by, "capacity": "20", "handling_accepted": True, "context_key": parent["recovery"]["current_context"]["context_key"]})
            require(status == 200 and result.get("ok"), "Redirect fixture has an actual collector agreement")
            status, result = send("kitchen", "handoff", {"allocation_id": parent["id"], "revision": result["revision"], "quantity": "20", "occurred_at": instant(), "note": "Twenty sealed boxes handed to the agreed collector."})
            require(status == 200 and result.get("physical_report_saved"), "Redirect starts with a real saved twenty-box kitchen handoff")
            private_location = "Outside the original receiving team's private loading gate"
            private_note = "Original access contact is unavailable; this note belongs to the blocked destination."
            issue = {"allocation_id": parent["id"], "revision": result["revision"], "quantity_in_custody": "20", "current_location": private_location, "handling_maintained": True, "note": private_note}
            status, rejected = send("coordinator", "record_destination_issue", issue)
            require(status == 422, "Coordinator cannot invent the collector's live custody attestation")
            status, reported = send("collector", "record_destination_issue", issue)
            require(status == 200 and reported.get("ok"), "Assigned collector records a blocked destination and the food actually in custody")
            status, body = request("/worklist", "coordinator")
            require(status == 200 and any(row["kind"] == "resolve_destination" and row.get("allocation", {}).get("id") == parent["id"] for row in body["items"]), "A destination issue appears immediately before the planned arrival deadline")
            status, body = request(parent_path, "recipient")
            visible_issue = body["record"]["recovery"]["redirect"].get("issue")
            require(private_location not in json.dumps(visible_issue) and private_note not in json.dumps(visible_issue), "Recipient views omit the collector's private location and issue note")
            status, body = request(parent_path, "coordinator")
            parent = body["record"]
            require(any(event["kind"] == "destination_unavailable" and event.get("quantity_in_custody") == "20" for event in body.get("history", [])), "Coordinator history names the actual destination report and its attested quantity")
            original_destination = parent["need"]["site"]
            status, before = request("/offers/" + str(fixture["offer"]), "coordinator")
            status, target = request("/needs/" + str(fixture["second_need"]), "coordinator")
            target = target["record"]
            redirect = {"allocation_id": parent["id"], "revision": parent["revision"], "target_need_id": target["id"], "target_need_revision": target["revision"], "quantity": "15", "reason": "The original team cannot receive; offer fifteen still-handled boxes to another approved receiving team."}
            status, rejected = send("collector", "redirect", redirect)
            require(status == 422, "Collector cannot approve a different receiving partner")
            status, offered = send("coordinator", "redirect", redirect)
            require(status == 200 and offered.get("ok"), "Coordinator creates an addressed redirect invitation from verified custody")
            child_id = str(offered["child_allocation_id"])
            child_path = "/allocations/" + child_id
            status, after = request("/offers/" + str(fixture["offer"]), "coordinator")
            require(after["record"]["held_quantity"] == before["record"]["held_quantity"] and after["record"]["collected_quantity"] == "20", "Redirect invitation holds receiving capacity without reserving kitchen stock or recording another handoff")
            status, body = request(parent_path, "coordinator")
            parent = body["record"]
            require(parent["quantity"] == "20" and parent["recovery"]["redirect"]["pending_quantity"] == "15", "Pending redirect reserves custody while the original promise stays intact")
            status, target_three = request("/needs/" + str(fixture["third_need"]), "coordinator")
            target_three = target_three["record"]
            status, rejected = send("coordinator", "redirect", dict(redirect, revision=parent["revision"], target_need_id=target_three["id"], target_need_revision=target_three["revision"], quantity="6"))
            require(status == 422, "Competing redirect cannot reserve custody already held for another reply")
            status, hidden = request(parent_path, "second_recipient")
            require(status == 404, "New receiving partner cannot open the original partner's private case")
            status, hidden = request(child_path, "recipient")
            require(status == 404, "Original receiving partner cannot open the new partner's addressed child case")
            status, body = request(child_path, "second_recipient")
            child = body["record"]
            serialized = json.dumps(body)
            require(status == 200 and child["recovery"]["redirect"]["parent_readable"] is False and original_destination["address"] not in serialized and original_destination["name"] not in serialized and private_location not in serialized and private_note not in serialized, "New recipient reads its invitation without the original destination or private custody details")
            status, rejected = send("second_recipient", "accept", {"allocation_id": child_id, "revision": child["revision"], "quantity": "10", "context_key": "obsolete-context"})
            require(status == 422, "Redirect acceptance rejects an obsolete offered context")
            status, accepted = send("second_recipient", "accept", {"allocation_id": child_id, "revision": child["revision"], "quantity": "10", "context_key": child["recovery"]["current_context"]["context_key"]})
            require(status == 200 and accepted.get("ok"), "New receiving partner can accept a partial redirect using the current offered context")
            status, body = request(child_path, "collector")
            child = body["record"]
            require(child["state"] == "collected" and child["recovery"]["redirect"]["transferred_in_quantity"] == "10" and child["recovery"]["stock_committed_quantity"] == "0", "Accepted child already has custody and requires no second kitchen pickup")
            status, body = request(parent_path, "coordinator")
            parent = body["record"]
            require(parent["recovery"]["redirect"]["transferred_out_quantity"] == "10" and parent["recovery"]["physical_unknown_quantity"] == "10", "Parent retains the exact food still in custody after a partial transfer")
            status, body = request("/needs/" + str(fixture["need"]), "recipient")
            require(body["record"]["state"] == "availability_review" and body["record"]["remaining_quantity"] == "0", "Original receiving capacity stays paused until its team confirms a fresh full need")
            status, body = request("/site", "second_recipient")
            site = body["record"]
            changed_site = {key: site[key] for key in ("revision", "name", "address", "entrance", "time_zone", "contact_phone")}
            changed_site["entrance"] = "Use the new east receiving entrance."
            status, changed = send("second_recipient", "save_site", changed_site)
            require(status == 200 and changed.get("ok"), "New receiving team can correct its own onward delivery instructions")
            status, changed = send("coordinator", "request_change", {"allocation_id": child_id, "revision": child["revision"], "new_quantity": "10", "reason": "The receiving entrance changed; confirm the current destination before onward delivery."})
            require(status == 200 and changed.get("ok"), "Changed target instructions require explicit receiving confirmation")
            status, body = request(child_path, "second_recipient")
            pending = body["record"]["recovery"]["change"]
            require(private_location not in json.dumps(pending["context"]) and private_note not in json.dumps(pending["context"]) and pending["context"]["details"]["destination"]["entrance"] == changed_site["entrance"], "Stored change context shows the new entrance without leaking the collector's private location")
            status, body = request("/needs/" + target["id"], "second_recipient")
            need = body["record"]
            status, agreed = send("second_recipient", "respond_change", {"change_id": pending["id"], "revision": pending["revision"], "agree": True, "need_total": need["requested_quantity"], "need_revision": need["revision"], "stock_source_id": None, "note": "Confirmed the current receiving entrance and full need."})
            require(status == 200 and agreed.get("state") == "applied", "New receiving partner confirms the changed destination before the collector agrees onward travel")
            status, body = request(child_path, "collector")
            child = body["record"]
            arrival = {"allocation_id": child_id, "revision": child["revision"], "context_key": child["recovery"]["current_context"]["context_key"], "arrival_by": (datetime.now(timezone.utc) + timedelta(minutes=15)).isoformat(), "capacity": "10", "handling_accepted": True}
            status, rejected = send("coordinator", "confirm_redirect", arrival)
            require(status == 422, "Coordinator cannot confirm the collector's redirected arrival")
            status, rejected = send("collector", "confirm_redirect", arrival)
            require(status == 422, "Redirected arrival capacity must cover all unresolved food still carried in the linked trip")
            status, confirmed = send("collector", "confirm_redirect", dict(arrival, capacity="20"))
            require(status == 200 and confirmed.get("ok"), "Assigned collector confirms the new destination and handling without another pickup")
            status, body = request(child_path, "second_recipient")
            child = body["record"]
            serialized = json.dumps(body)
            require(original_destination["address"] not in serialized and private_location not in serialized and private_note not in serialized, "Saved redirect trip remains private from the original destination's details")
            status, received = send("second_recipient", "receive", {"allocation_id": child_id, "revision": child["revision"], "quantity": "10", "occurred_at": instant(), "note": "Ten redirected boxes accepted by the new receiving team."})
            require(status == 200 and received.get("physical_report_saved"), "New receiving partner records the food actually accepted")
            status, body = request(child_path, "second_recipient")
            require(body["record"]["received_quantity"] == "10" and body["record"]["recovery"]["physical_unknown_quantity"] == "0", "Redirected receipt closes only the child's actual custody")
            status, after = request("/offers/" + str(fixture["offer"]), "kitchen")
            require(after["record"]["collected_quantity"] == "20", "Completed redirect never counts the original kitchen handoff twice")
            return json.dumps({"ok": True, "checks": checks, "count": len(checks), "fixture_network": fixture["network"], "redirect": True, "users_removed": True})
        status, body = request("/session")
        require("user" not in body, "Anonymous HTTP request receives no session data")
        status, body = request("/session", "nonmember")
        require(status == 403 and body.get("error", {}).get("code") == "MEMBERSHIP_REQUIRED", "An authenticated account without membership is refused (HTTP " + str(status) + "; code " + str(body.get("error", {}).get("code")) + ")")
        status, body = request("/session", "inactive")
        require(status == 403, "Inactive membership cannot read a session")
        jar = http.cookiejar.CookieJar()
        opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
        status, body = request("/session", "coordinator", opener=opener)
        require(status == 200 and body.get("user", {}).get("role") == "coordinator", "Session identity comes from the authenticated native account")
        status, body = request("/session", opener=opener)
        require(status == 200 and body.get("user", {}).get("id") == str(fixture["coordinator"]), "Native session cookie preserves the authenticated account")
        require(not any(key in body for key in ("password", "token", "cookie", "session_id")), "Session response contains no authentication secrets")
        status, body = request("/offers", "kitchen")
        require(status == 200 and {row["id"] for row in body["records"]} == {str(fixture["offer"])}, "Kitchen list is limited to its own organization")
        status, body = request("/offers/" + str(fixture["second_offer"]), "kitchen")
        require(status == 404, "Kitchen cannot read another kitchen by direct ID")
        status, body = request("/offers/" + str(fixture["foreign_offer"]), "coordinator")
        require(status == 404, "Coordinator cannot read another network by direct ID")
        status, body = request("/offers/" + str(fixture["offer"]), "coordinator")
        require(status == 200 and any(row["kind"] == "offer_confirmed" for row in body.get("history", [])), "Authorized case history contains actual recorded human actions (HTTP " + str(status) + "; code " + str(body.get("error", {}).get("code")) + ")")
        require(body.get("notifications") and all("recipient" not in row and "body" not in row for row in body["notifications"]), "Notification metadata stays separate and omits message content and addresses")
        status, body = request("/allocations", "recipient")
        require(status == 200 and {row["id"] for row in body["records"]} == {str(fixture["allocation"])}, "Recipient sees only invitations addressed to its organization")
        status, body = request("/allocations/" + str(fixture["allocation"]), "recipient")
        require(status == 200 and "history" not in body and "notifications" not in body, "Partner detail does not expose coordinator-only case metadata")
        status, body = request("/allocations/" + str(fixture["other_allocation"]), "recipient")
        require(status == 404, "Recipient cannot open another recipient's invitation")
        status, body = request("/allocations", "collector")
        require(status == 200 and {row["id"] for row in body["records"]} == {str(fixture["allocation"])}, "Collector sees only assigned pickup tickets")
        require("source_ids" not in body["records"][0]["offer"], "Pickup ticket does not expose source internals")
        status, body = request("/allocations/" + str(fixture["other_allocation"]), "collector")
        require(status == 404, "Collector cannot open an unassigned pickup ticket")
        status, body = request("/worklist", "recipient")
        require(status == 403, "Receiving contact cannot read the coordinator worklist")
        status, body = request("/worklist", "coordinator")
        require(status == 200 and any(item["kind"] == "plan_offer" and item.get("offer", {}).get("id") == str(fixture["offer"]) for item in body.get("items", [])), "Coordinator home shows current unassigned food as a real planning action")
        status, body = request("/allocations?need_id=" + str(fixture["second_need"]), "coordinator")
        require(status == 200 and {row["id"] for row in body["records"]} == {str(fixture["other_allocation"])}, "Case filters run before allocation pagination")
        status, body = request("/allocations?need_id=" + str(fixture["second_need"]), "recipient")
        require(status == 200 and body["records"] == [], "Case filters cannot widen recipient scope")
        status, body = request("/collectors", "recipient")
        require(status == 200 and {row["id"] for row in body["records"]} == {str(fixture["collector"])}, "Collector directory contains only approved same-network collectors (HTTP " + str(status) + "; code " + str(body.get("error", {}).get("code")) + ")")
        status, body = request("/collectors", "kitchen")
        require(status == 403, "Kitchen cannot browse the collector directory")
        status, body = request("/site", "kitchen")
        require(status == 200 and body.get("record", {}).get("name"), "Own-site endpoint reads confirmed saved partner details")
        status, body = request("/plans/" + str(fixture["foreign_offer"]), "coordinator")
        require(status == 404, "Saved-plan lookup cannot cross networks")
        status, body = request("/plans/" + str(fixture["offer"]), "recipient")
        require(status == 403, "Receiving contact cannot open coordinator planning history")
        status, body = request("/plans/" + str(fixture["offer"]), "coordinator")
        require(status == 200 and body.get("record", {}).get("run_id") == str(fixture["saved_plan"]) and body["record"].get("proposal"), "Saved proposal reopens from its stored fixture without another model call")
        require(body["record"].get("model") == "http-test-fixture-no-provider" and body["record"].get("tool_audit") == [] and body["record"].get("usage") is None, "Saved planning metadata reports its actual fixture origin and leaves unknown usage empty")
        preview = body["record"]["proposal"]
        status, before = request("/offers/" + str(fixture["offer"]), "coordinator")
        status, checked = request("/plan-check", "coordinator", preview)
        require(status == 200 and checked.get("check_only") is True and checked.get("reservation_created") is False, "Canonical proposal check validates current facts without creating a reservation (HTTP " + str(status) + "; code " + str(checked.get("error", {}).get("code")) + ")")
        status, after = request("/offers/" + str(fixture["offer"]), "coordinator")
        require(before["record"]["held_quantity"] == after["record"]["held_quantity"] and before["record"]["revision"] == after["record"]["revision"], "Checking a plan leaves saved stock and revisions unchanged")
        status, rejected = request("/plan-check", "recipient", preview)
        require(status == 403, "Receiving contact cannot run coordinator plan checks")
        preview["offer_revision"] -= 1
        status, rejected = request("/plan-check", "coordinator", preview)
        require(status == 422 and rejected.get("error", {}).get("code") == "STALE_OFFER", "Plan check uses the same current-revision policy as sending")
        command = {"request_id": "http-create-" + suffix, "action": "create_offer", "payload": {}}
        status, body = request("/commands", "kitchen", command, {"X-Allfedo-Request": ""})
        require(status == 403, "Browser write requires the Allfedo request header")
        status, body = request("/commands", "kitchen", command, {"Origin": "https://another.example"})
        require(status == 403, "Cross-site write is refused even with a forged request header")
        forged = dict(command, actor_id=str(fixture["coordinator"]))
        status, body = request("/commands", "kitchen", forged)
        require(status == 400, "Caller cannot supply another actor identity")
        now = datetime.now(timezone.utc)
        command["payload"] = {"description": "Sealed café meal boxes", "quantity": "6", "unit": "meal_box",
                              "ready_at": (now - timedelta(minutes=1)).isoformat(),
                              "collect_by": (now + timedelta(hours=1)).isoformat(),
                              "holding": "chilled", "present_allergens": [], "assessed_allergens": ["milk"],
                              "handling_until": (now + timedelta(hours=2)).isoformat(), "packaging": "Sealed boxes, three per carry bag",
                              "event_at": now.isoformat()}
        status, body = request("/commands", "kitchen", command)
        require(status == 200 and body.get("ok") and body.get("offer_id"), "Authenticated HTTP write passes through the native command production (HTTP " + str(status) + "; code " + str(body.get("error", {}).get("code")) + ")")
        offer_id = str(body["offer_id"])
        status, repeat = request("/commands", "kitchen", command)
        require(status == 200 and str(repeat.get("offer_id")) == offer_id, "HTTP retry returns the saved command outcome")
        status, detail = request("/offers/" + offer_id, "kitchen")
        require(status == 200 and detail["record"]["description"] == "Sealed café meal boxes", "HTTP write persists exact Unicode food details")
        command["payload"]["quantity"] = "7"
        status, body = request("/commands", "kitchen", command)
        require(status == 409 and body.get("error", {}).get("code") == "REQUEST_ID_REUSED", "Changed intention cannot reuse a saved HTTP request ID")

        # Real recovery commands stay inside this run's isolated partner network.
        status, body = request("/needs/" + str(fixture["need"]), "recipient")
        require(status == 200 and body["record"].get("receiving_from"), "Receiving reads include the partner's confirmed opening instant")
        allocation_path = "/allocations/" + str(fixture["allocation"])
        status, body = request(allocation_path, "collector")
        allocation = body["record"]
        context = allocation["recovery"]["current_context"]
        require(status == 200 and "evidence" not in context and context.get("context_key"), "Assigned collector reads current instructions and an opaque key without private evidence references")
        transport = {"allocation_id": allocation["id"], "revision": allocation["revision"], "pickup_at": (datetime.now(timezone.utc) + timedelta(minutes=2)).isoformat(), "arrival_by": (datetime.now(timezone.utc) + timedelta(minutes=20)).isoformat(), "capacity": "20", "handling_accepted": True, "context_key": "stale-context"}
        status, rejected = send("collector", "confirm_transport", transport)
        require(status == 422 and not rejected.get("ok"), "Collector cannot confirm instructions using an obsolete context key")
        transport["context_key"] = context["context_key"]
        status, confirmed = send("collector", "confirm_transport", transport)
        require(status == 200 and confirmed.get("ok"), "Assigned collector confirms the exact current trip instructions")
        status, body = request(allocation_path, "collector")
        original_trip = body["record"]["recovery"]["original_trip"]
        require(original_trip and original_trip == body["record"]["recovery"]["agreed_trip"] and "source_id" not in original_trip, "First agreed trip is saved as an immutable ticket without exposing its source record")
        status, body = request("/site", "kitchen")
        site = body["record"]
        changed_site = {key: site[key] for key in ("revision", "name", "address", "entrance", "time_zone", "contact_phone")}
        changed_site["entrance"] = "Use the courtyard gate; the loading entrance is closed."
        status, changed = send("kitchen", "save_site", changed_site)
        require(status == 200 and changed.get("ok"), "Kitchen can report changed pickup instructions through its own account")
        status, body = request(allocation_path, "collector")
        recovery = body["record"]["recovery"]
        require(recovery["original_trip"] == original_trip and recovery["agreed_trip"] == original_trip and recovery["current_context"]["details"]["pickup"]["entrance"] == changed_site["entrance"] and recovery["trip_needs_confirmation"] is True, "Changed pickup instructions remain separate from the collector's saved agreement")

        status, body = request(allocation_path, "recipient")
        receipt = {"allocation_id": body["record"]["id"], "revision": body["record"]["revision"], "quantity": "0", "occurred_at": instant(), "note": "No boxes have arrived; none accepted so far."}
        status, saved = send("recipient", "receive", receipt)
        require(status == 200 and saved.get("physical_report_saved"), "An actual zero receipt is saved as a report rather than treated as missing")
        status, body = request(allocation_path, "recipient")
        recovery = body["record"]["recovery"]
        report = next(row for row in recovery["custody_history"] if row["id"] == str(saved["custody_id"]))
        require(recovery["receipt_recorded"] is True and report["quantity"] == "0" and report["note"] == receipt["note"] and report["can_correct"] is True and "source_id" not in report, "Recipient sees its real zero report, explanation, and native correction permission")
        receipt["revision"] = body["record"]["revision"]
        status, rejected = send("recipient", "receive", receipt)
        require(status == 422, "A second initial zero receipt is refused; additional facts require an explicit later report or correction")
        correction = {"custody_id": report["id"], "revision": report["revision"], "quantity": "0", "occurred_at": instant(), "note": "Corrected the earlier report time after checking the receiving desk log."}
        status, rejected = send("kitchen", "correct_custody", correction)
        require(status == 422, "Kitchen cannot rewrite a receiving partner's physical report")
        status, corrected = send("recipient", "correct_custody", correction)
        require(status == 200 and corrected.get("supersedes_id") == report["id"], "Responsible recipient appends a correction while preserving the original report")
        status, body = request(allocation_path, "recipient")
        reports = body["record"]["recovery"]["custody_history"]
        require(any(row["id"] == report["id"] and not row["active"] and not row["can_correct"] for row in reports) and any(row["supersedes_id"] == report["id"] and row["active"] for row in reports), "Superseded and current physical reports remain distinguishable in the saved history")

        offer_path = "/offers/" + str(fixture["offer"])
        status, body = request(offer_path, "kitchen")
        counted_at = instant()
        status, counted = send("kitchen", "count_stock", {"offer_id": str(fixture["offer"]), "revision": body["record"]["revision"], "on_hand_quantity": "40", "occurred_at": counted_at, "note": "Counted all original boxes and checked that no returned boxes are present."})
        require(status == 200 and counted.get("observation_applied"), "Kitchen saves a current physical count without silently resuming invitations")
        status, body = request(offer_path, "kitchen")
        food = body["record"]
        require(food.get("stock_source_id") == str(counted["source_id"]) and food["stock_count"]["occurred_at"] == counted_at and food["stock_projection"] is not None and food["available_quantity"] == "0", "Kitchen reads the actual latest count source, full fractional occurrence time, and paused stock projection")
        status, body = request(allocation_path, "coordinator")
        current = body["record"]
        status, changed = send("coordinator", "request_change", {"allocation_id": current["id"], "revision": current["revision"], "new_quantity": "15", "reason": "Receiving partner requests five fewer boxes; kitchen must confirm the released boxes remain on site."})
        require(status == 200 and changed.get("state") == "awaiting_response", "Coordinator proposes a reduction without silently changing the promise")
        status, body = request(allocation_path, "recipient")
        current_change = body["record"]["recovery"]["change"]
        require(body["record"]["quantity"] == "20" and set(current_change["required_parties"]) == {"recipient", "kitchen"} and "evidence" not in current_change["context"], "Current promise stays intact while the addressed parties review their required replies")
        status, body = request("/needs/" + str(fixture["need"]), "recipient")
        need = body["record"]
        response = {"change_id": current_change["id"], "revision": current_change["revision"], "agree": True, "need_total": need["requested_quantity"], "need_revision": need["revision"], "stock_source_id": None, "note": "Confirmed the full remaining receiving need with the duty coordinator."}
        status, rejected = send("second_recipient", "respond_change", response)
        require(status == 422, "Another receiving organization cannot answer this promise change")
        status, answered = send("recipient", "respond_change", response)
        require(status == 200 and answered.get("allocation_id") == current["id"], "Receiving reply records an explicit full need and returns the saved case identity")
        status, body = request(allocation_path, "kitchen")
        current_change = body["record"]["recovery"]["change"]
        require(current_change["responses"]["recipient"]["status"] == "agreed" and body["record"]["quantity"] == "20", "One required reply cannot apply the reduction before kitchen confirmation")
        status, answered = send("kitchen", "respond_change", {"change_id": current_change["id"], "revision": current_change["revision"], "agree": True, "need_total": None, "need_revision": None, "stock_source_id": food["stock_source_id"], "note": "The latest count confirms the released boxes are physically at the kitchen."})
        require(status == 200 and answered.get("state") == "applied", "Promise reduction applies only after both required parties confirm current facts")
        status, body = request(allocation_path, "recipient")
        final_case = body["record"]
        require(final_case["quantity"] == "15" and final_case["recovery"]["stock_committed_quantity"] == "15" and final_case["recovery"]["original_promise_quantity"] == "20", "Read model preserves the original promise and exposes the actual remaining stock commitment")
        status, body = request("/logout", command={}, opener=opener)
        require(status == 200 and body.get("signed_out"), "Logout ends the native authenticated session")
        status, body = request("/session", opener=opener)
        require(status == 401 and "user" not in body, "Ended session cannot read data with its old cookie")

        class LoginForm(HTMLParser):
            def __init__(self):
                super().__init__()
                self.values = {}
                self.action = ""
            def handle_starttag(self, tag, attrs):
                fields = dict(attrs)
                if tag == "form":
                    self.action = fields.get("action", "")
                if tag == "input" and fields.get("type", "").lower() == "hidden" and fields.get("name"):
                    self.values[fields["name"]] = fields.get("value", "")

        browser = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        app_url = baseURL.rsplit("/api", 1)[0] + "/"
        with browser.open(app_url, timeout=15) as page:
            form = LoginForm()
            form.feed(page.read().decode("utf-8"))
        form.values.update({"IRISUsername": accounts["kitchen"]["username"], "IRISPassword": accounts["kitchen"]["password"]})
        login = urllib.request.Request(urllib.parse.urljoin(app_url, form.action), data=urllib.parse.urlencode(form.values).encode(), headers={"Content-Type": "application/x-www-form-urlencoded", "Origin": app_url.rstrip("/").rsplit("/allfedo", 1)[0]})
        with browser.open(login, timeout=15) as page:
            page.read()
        status, body = request("/session", opener=browser)
        require(status == 200 and body.get("user", {}).get("role") == "kitchen", "Native login form authenticates the shared API session without JavaScript passwords")
        return json.dumps({"ok": True, "checks": checks, "count": len(checks), "fixture_network": fixture["network"], "users_removed": True})
    finally:
        iris.cls("AllfedoWebScenario").RemoveUsers(credentials)
}
}
