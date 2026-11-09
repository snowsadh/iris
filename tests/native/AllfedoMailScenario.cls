/// Saved-command mail guards and readable text. SMTP delivery is a separate channel check.
Class AllfedoMailScenario Extends %RegisteredObject
{
ClassMethod Run() As %DynamicObject
{
    Do ##class(AllfedoScenario).Setup(.ids)
    Set checks=[],held=##class(AllfedoScenario).Run(ids.coordinator,"mail-invitation","apply_plan",##class(AllfedoScenario).Plan(ids.coordinator,ids.offer,ids.need,"20"))
    Do ..Expect(held.ok,"A real current plan creates the invitation notice.",checks)
    Set allocationId=held."allocation_ids".%Get(0),allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId),invitation=..Notice(allocationId,"invitation",ids.recipient)
    Do ..Expect(##class(Allfedo.Operation.Mail).ObsoleteReason(invitation,allocation)="","A current addressed invitation is eligible for delivery.",checks)
    Set text=##class(Allfedo.Operation.Mail).Text(invitation,allocation),context=##class(Allfedo.Recovery).CurrentContext(allocation)
    Do ..Expect(text[("Open the saved case: "_##class(Allfedo.Operation.Mail).PublicURL()_"#/allocations/"_allocationId),"Invitation links to the saved authenticated case.",checks)
    Do ..Expect(text[##class(Allfedo.Operation.Mail).At(##class(Allfedo.Policy).ISO(allocation.HoldUntil),context.details.destination."time_zone"),"Invitation gives its actual reply deadline in the destination's time zone.",checks)
    Do ..Expect((text["Handling deadline:")&&(text[##class(Allfedo.Operation.Mail).At(context.details.food."handling_until",context.details.pickup."time_zone")),"Food handling deadline is explicit, separate from the collection window.",checks)
    Do ..Expect((text["temporary hold")&&(text["no collector or trip is confirmed")&&(text["Email delivery does not confirm acceptance, collection or receipt"),"Email does not invent acceptance or physical outcomes.",checks)

    Set recipient=##class(Allfedo.Rescue).Actor(ids.recipient),originalEmail=recipient.Email
    Set recipient.Email="changed-contact@example.test"
    Do ##class(Allfedo.Rescue).Save(recipient)
    Do ..Expect(##class(Allfedo.Operation.Mail).ObsoleteReason(invitation,allocation)'="","A changed email address stops delivery to the old address.",checks)
    Set recipient.Email=originalEmail,recipient.Active=0
    Do ##class(Allfedo.Rescue).Save(recipient)
    Do ..Expect(##class(Allfedo.Operation.Mail).ObsoleteReason(invitation,allocation)'="","An inactive addressed account cannot receive an actionable notice.",checks)
    Set recipient.Active=1
    Do ##class(Allfedo.Rescue).Save(recipient)
    Set colleague=##class(Allfedo.Record.Actor).%New()
    Set colleague.NetworkId=ids.network,colleague.OrganizationId=recipient.OrganizationId,colleague.Role="recipient",colleague.DisplayName="Morgan Ellis",colleague.Email="receiving-duty@example.test",colleague.UserName=ids.network_"-receiving-colleague"
    Do ##class(Allfedo.Rescue).Save(colleague)
    Set need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids.need)
    Set refreshed=##class(AllfedoScenario).Run(colleague.%Id(),"mail-contact-handover","update_need",{"need_id":(ids.need),"revision":(need.Revision),"quantity":(""_need.RequestedQuantity),"unit":(need.Unit),"receiving_from":(##class(Allfedo.Policy).ISO(need.ReceivingFrom)),"receiving_until":(##class(Allfedo.Policy).ISO(need.ReceivingUntil)),"confirmed_until":(##class(Allfedo.Policy).ISO(need.ConfirmedUntil)),"excluded_allergens":[],"accepted_holding":["chilled"],"event_at":(##class(Allfedo.Policy).NowISO())})
    Do ..Expect(refreshed.ok&&(##class(Allfedo.Operation.Mail).ObsoleteReason(invitation,allocation)=""),"Another approved staff contact can refresh the same need without silently dropping the original staff member's invitation.",checks)
    Set accepted=##class(AllfedoScenario).Run(ids.recipient,"mail-accept","accept",{"allocation_id":(allocationId),"revision":1,"quantity":"20","context_key":(##class(AllfedoScenario).ContextKey(allocationId))}),allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId)
    Do ..Expect(accepted.ok&&(##class(Allfedo.Operation.Mail).ObsoleteReason(invitation,allocation)'=""),"An accepted invitation cannot later be delivered as awaiting its original reply.",checks)

    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
    Set counted=##class(AllfedoScenario).Run(ids.kitchen,"mail-count","count_stock",{"offer_id":(ids.offer),"revision":(food.Revision),"on_hand_quantity":"40","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Counted all boxes before agreeing to release five from the promise."})
    Set proposed=##class(AllfedoScenario).Run(ids.coordinator,"mail-change","request_change",{"allocation_id":(allocationId),"revision":(allocation.Revision),"new_quantity":"15","reason":"The receiving team needs five fewer boxes; confirm the full current need and kitchen stock."})
    Do ..Expect(counted.ok&&proposed.ok,"A real current count and coordinator request create a pending promise change.",checks)
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids.need)
    Set receivingRequest=..Notice(allocationId,"change_request",need.ContactActorId),kitchenRequest=..Notice(allocationId,"change_request",ids.kitchen)
    Do ..Expect((##class(Allfedo.Operation.Mail).ObsoleteReason(receivingRequest,allocation)="")&&(##class(Allfedo.Operation.Mail).ObsoleteReason(kitchenRequest,allocation)=""),"Required recipients can receive a change request after the original invitation was accepted.",checks)
    Set text=##class(Allfedo.Operation.Mail).Text(receivingRequest,allocation)
    Do ..Expect((text["Proposed change: 20 to 15 meal boxes")&&(text["A proposal alone does not change the promise"),"Change-request text distinguishes a proposal from a saved promise.",checks)
    Set answered=##class(AllfedoScenario).Run(need.ContactActorId,"mail-recipient-agrees","respond_change",{"change_id":(proposed."change_id"),"revision":(proposed."change_revision"),"agree":true,"need_total":"50","need_revision":(need.Revision),"stock_source_id":null,"note":"Confirmed the full current receiving need."})
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId)
    Do ..Expect(answered.ok&&(##class(Allfedo.Operation.Mail).ObsoleteReason(receivingRequest,allocation)'="")&&(##class(Allfedo.Operation.Mail).ObsoleteReason(kitchenRequest,allocation)=""),"A saved receiving reply stops only that reply request while the kitchen still needs to answer.",checks)
    Set applied=##class(AllfedoScenario).Run(ids.kitchen,"mail-kitchen-agrees","respond_change",{"change_id":(proposed."change_id"),"revision":(answered.revision),"agree":true,"need_total":null,"need_revision":null,"stock_source_id":(counted."source_id"),"note":"The latest physical count confirms the released boxes remain at the kitchen."})
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId),savedNotice=..Notice(allocationId,"change_applied",need.ContactActorId)
    Do ..Expect(applied.ok&&(applied.state="applied")&&(##class(Allfedo.Operation.Mail).ObsoleteReason(savedNotice,allocation)="")&&(##class(Allfedo.Operation.Mail).ObsoleteReason(kitchenRequest,allocation)'=""),"An applied change sends its factual notice and ends earlier requests for replies.",checks)
    Set text=##class(Allfedo.Operation.Mail).Text(savedNotice,allocation)
    Do ..Expect((text["Saved promise change: 20 to 15 meal boxes")&&(text["Later updates may already exist"),"Applied-change text preserves the specific saved change and directs readers to current facts.",checks)
    Set observed=##class(AllfedoScenario).Run(ids.recipient,"mail-later-zero-receipt","receive",{"allocation_id":(allocationId),"revision":(allocation.Revision),"quantity":"0","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"No food has arrived yet; this report does not erase the saved change."})
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId)
    Do ..Expect(observed.ok&&(allocation.Revision'=savedNotice.AllocationRevision)&&(##class(Allfedo.Operation.Mail).ObsoleteReason(savedNotice,allocation)=""),"A later real case update does not erase a factual applied-change notice.",checks)

    Set held=##class(AllfedoScenario).Run(ids.coordinator,"mail-second-invitation","apply_plan",##class(AllfedoScenario).Plan(ids.coordinator,ids."second_offer",ids."second_need","5"))
    Do ..Expect(held.ok,"A separate current invitation exists for withdrawal.",checks)
    Set withdrawnId=held."allocation_ids".%Get(0),originalRequest=..Notice(withdrawnId,"invitation",ids."second_recipient")
    Set withdrawn=##class(AllfedoScenario).Run(ids.coordinator,"mail-withdraw","withdraw_invitation",{"allocation_id":(withdrawnId),"revision":1,"reason":"These boxes are no longer offered; do not arrange collection."})
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",withdrawnId),withdrawal=..Notice(withdrawnId,"withdrawn",ids."second_recipient")
    Do ..Expect(withdrawn.ok&&(allocation.State="released")&&(##class(Allfedo.Operation.Mail).ObsoleteReason(originalRequest,allocation)'="")&&(##class(Allfedo.Operation.Mail).ObsoleteReason(withdrawal,allocation)=""),"Withdrawal ends the invitation while its factual withdrawal notice remains deliverable.",checks)
    Do ..Expect(##class(Allfedo.Operation.Mail).Text(withdrawal,allocation)["do not arrange collection","Withdrawal text keeps the coordinator's concrete instruction.",checks)
    Set formats=##class(Allfedo.Rescue).Parse(..CheckFormats())
    Do ..Expect(formats.ok,"Public URLs reject unsafe input and actual Python time zones handle clock changes.",checks)
    Quit {"ok":true,"count":(checks.%Size()),"checks":(checks),"fixture_network":(ids.network),"smtp_tested":false}
}

/// Actual onward commands exercise notice purposes; these checks do not assert SMTP delivery.
ClassMethod TestRedirectNotices() As %DynamicObject
{
    Do ##class(AllfedoScenario).Setup(.ids)
    Set checks=[],parentId=##class(AllfedoScenario).ReadyCase(ids,"20")
    Set handed=##class(AllfedoScenario).Run(ids.kitchen,"mail-onward-handoff","handoff",{"allocation_id":(parentId),"revision":4,"quantity":"10","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Ten boxes were handed over; ten remain at the kitchen."})
    Set reported=##class(AllfedoScenario).Run(ids.collector,"mail-onward-issue","record_destination_issue",{"allocation_id":(parentId),"revision":(handed.revision),"quantity_in_custody":"10","current_location":"Private vehicle location near the original destination","handling_maintained":true,"note":"Private original-destination access note."})
    Do ..Expect(handed.ok&&reported.ok,"Onward notices start with actual handed-over food and the collector's saved destination report.",checks)
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
    Set counted=##class(AllfedoScenario).Run(ids.kitchen,"mail-onward-count","count_stock",{"offer_id":(ids.offer),"revision":(food.Revision),"on_hand_quantity":"30","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Thirty boxes remain physically at the kitchen, including ten in the unavailable destination's promise."})
    Set released=##class(AllfedoScenario).Run(ids.coordinator,"mail-onward-release","release_unavailable",{"allocation_id":(parentId),"revision":(reported.revision),"stock_source_id":(counted."source_id"),"quantity":"10","reason":"Ten unhanded boxes remain at the kitchen; their promise to the unavailable destination is cancelled."})
    Do ..Expect(counted.ok&&released.ok,"Kitchen count and coordinator command release only the actual unhanded remainder.",checks)
    Set parent=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",parentId),releaseNotice=..Notice(parentId,"unavailable_released",ids.recipient)
    Do ..Expect((parent.State'="held")&&(##class(Allfedo.Operation.Mail).ObsoleteReason(releaseNotice,parent)=""),"A saved unhanded-release notice remains deliverable after the invitation stage.",checks)
    Set target=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids."second_need")
    Set proposed=##class(AllfedoScenario).Run(ids.coordinator,"mail-onward-propose","redirect",{"allocation_id":(parentId),"revision":(parent.Revision),"target_need_id":(ids."second_need"),"target_need_revision":(target.Revision),"quantity":"5","reason":"Another approved receiving team can accept five of the boxes already with the collector."})
    Do ..Expect(proposed.ok,"A real redirect command creates the new recipient's receiving-only invitation.",checks)
    Set childId=proposed."child_allocation_id",child=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",childId),invitation=..Notice(childId,"redirect_invitation",ids."second_recipient"),collector=##class(Allfedo.Rescue).Actor(ids.collector)
    Do ..Expect(##class(Allfedo.Operation.Mail).ObsoleteReason(invitation,child)="","An addressed current redirect invitation is eligible for delivery.",checks)
    Set text=##class(Allfedo.Operation.Mail).Text(invitation,child),context=##class(Allfedo.Recovery).CurrentContext(child)
    Do ..Expect((text[collector.DisplayName)&&(text["No kitchen pickup is needed")&&'(text["Ready:")&&'(text["Collect before:"),"Redirect invitation names the existing collector and never invents another kitchen pickup.",checks)
    Do ..Expect((text[##class(Allfedo.Operation.Mail).At(##class(Allfedo.Policy).ISO(child.HoldUntil),context.details.destination."time_zone"))&&(text["Handling deadline:")&&(text["Receiving from:")&&(text["Receiving before:"),"Onward invitation preserves the reply, food-handling and new receiving deadlines.",checks)
    Set oldSite=##class(Allfedo.Facts).SiteFor(ids.network,"westside-center")
    Do ..Expect('(text[oldSite.Name)&&'(text[oldSite.Address)&&'(text["Private vehicle location")&&'(text["Private original-destination access note"),"New recipient's email omits the original receiving site and private collector report.",checks)
    Set accepted=##class(AllfedoScenario).Run(ids."second_recipient","mail-onward-accept","accept",{"allocation_id":(childId),"revision":1,"quantity":"4","context_key":(##class(AllfedoScenario).ContextKey(childId))})
    Set child=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",childId),parent=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",parentId),onward=..Notice(childId,"redirect_accepted",ids.collector),moved=..Notice(parentId,"redirected",ids.recipient)
    Do ..Expect(accepted.ok&&(##class(Allfedo.Operation.Mail).ObsoleteReason(invitation,child)'="")&&(##class(Allfedo.Operation.Mail).ObsoleteReason(onward,child)=""),"Accepting the redirect ends the reply invitation and creates the collector's actual onward-confirmation notice.",checks)
    Set text=##class(Allfedo.Operation.Mail).Text(onward,child)
    Do ..Expect((text["accepted 4 meal boxes already in your custody")&&(text["not another kitchen pickup"),"Collector notice uses the quantity actually accepted by the new receiving team.",checks)
    Set collector.Active=0
    Do ##class(Allfedo.Rescue).Save(collector)
    Do ..Expect(##class(Allfedo.Operation.Mail).ObsoleteReason(onward,child)'="","An inactive collector cannot receive an actionable onward-confirmation notice.",checks)
    Set collector.Active=1
    Do ##class(Allfedo.Rescue).Save(collector)
    Do ..Expect(##class(Allfedo.Operation.Mail).ObsoleteReason(moved,parent)="","Original recipient's factual transfer notice survives the changed promise.",checks)
    Set confirmed=##class(AllfedoScenario).Run(ids.collector,"mail-onward-confirm","confirm_redirect",{"allocation_id":(childId),"revision":(child.Revision),"context_key":(##class(AllfedoScenario).ContextKey(childId)),"arrival_by":(##class(Allfedo.Policy).ISO(##class(Allfedo.Policy).Now()+900)),"capacity":"10","handling_accepted":true})
    Set child=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",childId)
    Do ..Expect(confirmed.ok&&(##class(Allfedo.Operation.Mail).ObsoleteReason(onward,child)'=""),"Saved onward agreement stops the earlier request for collector confirmation.",checks)
    Set actual=##class(AllfedoScenario).Run(ids.recipient,"mail-onward-original-zero","receive",{"allocation_id":(parentId),"revision":(parent.Revision),"quantity":"0","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"The original team accepted none; the earlier transfer remains a saved fact."})
    Set parent=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",parentId)
    Do ..Expect(actual.ok&&(parent.Revision'=moved.AllocationRevision)&&(##class(Allfedo.Operation.Mail).ObsoleteReason(moved,parent)="")&&(##class(Allfedo.Operation.Mail).ObsoleteReason(releaseNotice,parent)=""),"Later physical reports do not erase factual transfer or unhanded-release notices.",checks)
    Quit {"ok":true,"count":(checks.%Size()),"checks":(checks),"fixture_network":(ids.network),"smtp_tested":false}
}

/// Fresh collector reports can obsolete an unanswered invitation without changing its saved reply state.
ClassMethod TestStaleRedirectNotices() As %DynamicObject
{
    Set checks=[]
    For concern="quantity","handling" {
        Do ##class(AllfedoScenario).Setup(.ids)
        Set parentId=##class(AllfedoScenario).ReadyCase(ids,"20")
        Set handed=##class(AllfedoScenario).Run(ids.kitchen,"stale-mail-handoff","handoff",{"allocation_id":(parentId),"revision":4,"quantity":"20","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Twenty boxes handed to the collector."})
        Set reported=##class(AllfedoScenario).Run(ids.collector,"stale-mail-original-report","record_destination_issue",{"allocation_id":(parentId),"revision":(handed.revision),"quantity_in_custody":"20","current_location":"Reported vehicle location","handling_maintained":true,"note":"Twenty boxes are present and handling has been maintained."})
        Set target=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids."second_need")
        Set offered=##class(AllfedoScenario).Run(ids.coordinator,"stale-mail-offer","redirect",{"allocation_id":(parentId),"revision":(reported.revision),"target_need_id":(ids."second_need"),"target_need_revision":(target.Revision),"quantity":"15","reason":"Please review fifteen boxes already with the collector."})
        Do ##class(AllfedoScenario).Check(handed.ok&&reported.ok&&offered.ok,"The stale-notice check requires a real current handoff, report and fifteen-box invitation.")
        Set child=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",offered."child_allocation_id"),notice=..Notice(child.%Id(),"redirect_invitation",ids."second_recipient")
        Do ..Expect(##class(Allfedo.Operation.Mail).ObsoleteReason(notice,child)="","The "_concern_" fixture begins with a deliverable fifteen-box redirect invitation.",checks)
        Set quantity=$Select(concern="quantity":"10",1:"20"),maintained=(concern'="handling")
        Set report={"allocation_id":(parentId),"revision":(offered.revision),"quantity_in_custody":(""_quantity),"current_location":"Updated reported vehicle location","handling_maintained":true,"note":($Select(concern="quantity":"Only ten boxes are now confirmed present; the rest are unlocated.",1:"All twenty boxes are present, but the collector reports a break in the required holding condition."))}
        Do report.%Set("handling_maintained",maintained,"boolean")
        Set current=##class(AllfedoScenario).Run(ids.collector,"stale-mail-current-report","record_destination_issue",report)
        Set child=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",child.%Id())
        Do ..Expect(current.ok&&(child.State="held")&&(child.Revision=notice.AllocationRevision),"A new "_concern_" report is saved without pretending the target already replied.",checks)
        Do ..Expect(##class(Allfedo.Operation.Mail).ObsoleteReason(notice,child)'="","The queued redirect invitation is obsolete after the collector's "_concern_" report.",checks)
    }
    Quit {"ok":true,"count":(checks.%Size()),"checks":(checks),"smtp_tested":false}
}

/// Actual native scheduling and SMTP into the local Mailpit container, without a direct Deliver call.
ClassMethod TestScheduled() As %DynamicObject
{
    Do ##class(AllfedoScenario).Setup(.ids)
    Set original=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer),source=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",original.SourceId),food=##class(Allfedo.Rescue).Parse(source.BodyJSON)
    Set food.description="Sealed vegetable rice · café · 食事"
    Set created=##class(AllfedoScenario).Run(ids.kitchen,"smtp-unicode-offer","create_offer",food)
    Do ##class(AllfedoScenario).Check(created.ok,"The scheduled-mail fixture must save its Unicode food description.")
    Set ids.offer=created."offer_id"
    Set plan=##class(AllfedoScenario).Plan(ids.coordinator,ids.offer,ids.need,"10")
    Set held=##class(AllfedoScenario).Run(ids.coordinator,"scheduled-mail-proof","apply_plan",plan)
    Do ##class(AllfedoScenario).Check(held.ok,"Scheduled delivery needs a real saved invitation.")
    Set allocationId=held."allocation_ids".%Get(0),item=..Notice(allocationId,"invitation",ids.recipient),outboxId=item.%Id(),deadline=##class(Allfedo.Policy).Now()+20
    For {
        Set item=##class(Allfedo.Rescue).Open("Allfedo.Record.Outbox",outboxId)
        Quit:item.State="sent"
        Do ##class(AllfedoScenario).Check('$ListFind($ListBuild("failed","superseded"),item.State),"The valid invitation failed or became obsolete before scheduled SMTP delivery.")
        Do ##class(AllfedoScenario).Check(##class(Allfedo.Policy).Now()<deadline,"Native scheduling did not deliver its saved invitation within twenty seconds.")
        Hang .1
    }
    Do ##class(AllfedoScenario).Check(item.Attempts>0,"A saved sent result must come from an actual delivery attempt.")
    Set inbox=##class(Allfedo.Rescue).Parse(..CheckInbox(allocationId,##class(Allfedo.Operation.Mail).PublicURL()))
    Do ##class(AllfedoScenario).Check(inbox.ok,"Mailpit did not contain the scheduled invitation, its case link and handling deadline.")
    Quit {"ok":true,"smtp_tested":true,"scheduled":true,"allocation_id":(allocationId),"outbox_id":(""_outboxId),"attempts":(item.Attempts),"mailpit_message_id":(inbox."message_id")}
}

ClassMethod CheckInbox(allocationId As %String, publicURL As %String) As %String [ Language = python, Private ]
{
    import json
    import urllib.request
    import time
    browser = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        with browser.open("http://mailpit:8025/api/v1/messages?limit=100", timeout=5) as response:
            messages = json.load(response).get("messages", [])
        for item in messages:
            # Preview identifies the case without fetching unrelated complete messages.
            if "Allfedo | Collection " + allocationId not in item.get("Snippet", ""):
                continue
            with browser.open("http://mailpit:8025/api/v1/message/" + item["ID"], timeout=5) as response:
                message = json.load(response)
            text = message.get("Text", "")
            if (text.splitlines()[0] == "Allfedo | Collection " + allocationId
                    and "Open the saved case: " + publicURL + "#/allocations/" + allocationId in text.splitlines()
                    and "Handling deadline:" in text
                    and "Sealed vegetable rice · café · 食事" in text
                    and "Email delivery does not confirm acceptance" in text):
                return json.dumps({"ok": True, "message_id": item["ID"]})
        time.sleep(.1)
    return json.dumps({"ok": False})
}

ClassMethod Notice(allocationId As %String, purpose As %String, actorId As %String) As Allfedo.Record.Outbox [ Private ]
{
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 1 ID FROM Allfedo_Record.Outbox WHERE AllocationId=? AND Purpose=? AND RecipientActorId=? ORDER BY ID DESC",allocationId,purpose,actorId)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set found=query.%Next()
    Do ##class(Allfedo.Rescue).QueryOK(query),##class(AllfedoScenario).Check(found,"The real command did not save its expected notification.")
    Quit ##class(Allfedo.Rescue).Open("Allfedo.Record.Outbox",query.ID)
}

ClassMethod Expect(condition As %Boolean, message As %String, checks As %DynamicArray) [ Private ]
{
    Do ##class(AllfedoScenario).Check(condition,message),checks.%Push(message)
}

ClassMethod CheckFormats() As %String [ Language = python, Private ]
{
    import iris
    import json
    mail = iris.cls("Allfedo.Operation.Mail")
    assert mail.PublicURL("https://rescue.example.test:8443/allfedo") == "https://rescue.example.test:8443/allfedo/"
    for value in ("https://person:password@example.test/allfedo/", "https://example.test/allfedo/?token=example", "https://example.test/allfedo/#case", "https://example.test:70000/allfedo/", "https://example.test/other/", "https://example.test/allfedo/\r\n", "file:///allfedo/"):
        try:
            mail.PublicURL(value)
        except Exception:
            pass
        else:
            raise AssertionError("Unsafe public application URL was accepted.")
    assert mail.At("2026-03-29T00:30:00Z", "Europe/London").endswith("00:30 GMT")
    assert mail.At("2026-03-29T01:30:00Z", "Europe/London").endswith("02:30 BST")
    assert mail.At("2026-10-25T00:30:00Z", "Europe/London").endswith("01:30 BST")
    assert mail.At("2026-10-25T01:30:00Z", "Europe/London").endswith("01:30 GMT")
    assert mail.At("", "Europe/London") == "Not confirmed"
    return json.dumps({"ok": True})
}
}
