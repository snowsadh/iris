/// Input parsing and the Embedded Python invitation policy. No storage or model calls.
Class Allfedo.Policy Extends %RegisteredObject
{
ClassMethod Now() As %BigInt
{
    Set utc = $ZTIMESTAMP
    Quit ($Piece(utc, ",", 1) * 86400) + ($Piece($Piece(utc, ",", 2), ".", 1))
}

ClassMethod ISO(seconds As %BigInt) As %String
{
    Quit $Translate($ZDATETIME((seconds \ 86400)_","_(seconds # 86400), 3), " ", "T")_"Z"
}

/// Server UTC with fractions; physical ordering must not be reduced to the integer index columns.
ClassMethod NowISO() As %String
{
    Quit $Translate($ZDATETIME($ZTIMESTAMP,3,1,6)," ","T")_"Z"
}

ClassMethod Instant(value As %String) As %BigInt [ Language = python ]
{
    from datetime import datetime, timezone
    instant = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if instant.utcoffset() is None:
        raise ValueError("Use a full date, time, and UTC offset.")
    return int((instant.astimezone(timezone.utc) - datetime(1840, 12, 31, tzinfo=timezone.utc)).total_seconds())
}

ClassMethod Validate(snapshot As %String, proposal As %String) As %String [ Language = python ]
{
    import json
    from allfedo.invitations import validate_invitation_plan
    return json.dumps(validate_invitation_plan(json.loads(snapshot), json.loads(proposal)))
}

/// Reject unknown fields rather than silently accepting misspelled intentions.
ClassMethod Normalize(action As %String, payload As %String) As %String [ Language = python ]
{
    import json
    import re
    def normalize():
        fields = {
            "create_offer": {"description", "quantity", "unit", "ready_at", "collect_by", "holding", "handling_until", "packaging", "present_allergens", "assessed_allergens", "event_at"},
            "save_site": {"revision", "name", "address", "entrance", "time_zone", "contact_phone"},
            "confirm_food": {"offer_id", "revision", "ready_at", "collect_by", "holding", "handling_until", "packaging", "present_allergens", "assessed_allergens", "event_at"},
            "update_need": {"need_id", "revision", "quantity", "unit", "receiving_from", "receiving_until", "confirmed_until", "excluded_allergens", "accepted_holding", "event_at"},
            "create_need": {"quantity", "unit", "receiving_from", "receiving_until", "confirmed_until", "excluded_allergens", "accepted_holding", "event_at"},
            "apply_plan": {"offer_id", "offer_revision", "requests", "reason"},
            "accept": {"allocation_id", "revision", "quantity"},
            "decline": {"allocation_id", "revision", "reason"},
            "assign_collector": {"allocation_id", "revision", "collector_actor_id"},
            "confirm_transport": {"allocation_id", "revision", "pickup_at", "arrival_by", "capacity", "handling_accepted", "context_key"},
            "handoff": {"allocation_id", "revision", "quantity", "occurred_at", "note"},
            "receive": {"allocation_id", "revision", "quantity", "occurred_at", "note"},
            "count_stock": {"offer_id", "revision", "on_hand_quantity", "occurred_at", "note"},
            "withdraw_invitation": {"allocation_id", "revision", "reason"},
            "request_change": {"allocation_id", "revision", "new_quantity", "reason"},
            "respond_change": {"change_id", "revision", "agree", "need_total", "need_revision", "stock_source_id", "note"},
            "record_disposition": {"allocation_id", "revision", "quantity", "outcome", "occurred_at", "note"},
            "correct_custody": {"custody_id", "revision", "quantity", "occurred_at", "note"},
            "receive_more": {"allocation_id", "revision", "quantity", "occurred_at", "note"},
            "dispose_quarantined": {"offer_id", "revision", "quantity", "occurred_at", "note"},
            "acknowledge_trip": {"allocation_id", "revision", "context_key", "capacity", "handling_accepted", "arrival_by"},
            "resume_offer": {"offer_id", "revision"},
            "expire_hold": {"allocation_id", "revision"},
        }
        if action not in fields:
            raise ValueError("Unknown command action.")
        item = json.loads(payload)
        if not isinstance(item, dict) or set(item) != fields[action]:
            raise ValueError("Supply exactly the documented fields for " + action + ".")
        for name, value in item.items():
            if name in {"need_total", "need_revision", "stock_source_id"} and value is None:
                continue
            if name in {"ready_at", "collect_by", "receiving_from", "receiving_until", "confirmed_until", "event_at", "pickup_at", "arrival_by", "handling_until", "occurred_at"}:
                if name == "handling_until" and value is None:
                    continue
                from datetime import datetime
                try:
                    instant = datetime.fromisoformat(value.replace("Z", "+00:00"))
                    if instant.utcoffset() is None:
                        raise ValueError("missing offset")
                    from datetime import timezone
                    item[name] = instant.astimezone(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
                except (AttributeError, TypeError, ValueError, OverflowError):
                    raise ValueError(name + " needs a full date, time, and UTC offset.") from None
            elif name in {"quantity", "capacity", "new_quantity", "on_hand_quantity", "need_total"}:
                if not isinstance(value, str) or not re.fullmatch(r"[0-9]{1,6}", value):
                    raise ValueError(name + " must be a whole-number string, at most 999999.")
            elif name in {"revision", "offer_revision", "need_revision"}:
                if type(value) is not int or value < (0 if action == "save_site" else 1):
                    raise ValueError(name + " must be a positive integer.")
            elif name == "holding" and value is None:
                continue
            elif name in {"packaging", "entrance", "contact_phone"}:
                if not isinstance(value, str) or len(value) > (100 if name == "contact_phone" else 1000):
                    raise ValueError(name + " must be text within its length limit; leave it empty when unknown.")
            elif name in {"name", "address", "time_zone"}:
                if not isinstance(value, str) or not value.strip() or len(value) > (1000 if name == "address" else 200):
                    raise ValueError(name + " needs the partner's real confirmed details.")
            elif name.endswith("_id") or name in {"description", "reason", "unit", "holding", "context_key", "outcome"}:
                if not isinstance(value, str) or not value.strip() or len(value) > 500:
                    raise ValueError(name + " needs nonempty text, at most 500 characters.")
            elif name == "note":
                if not isinstance(value, str) or len(value) > 2000:
                    raise ValueError("A note must be text, at most 2000 characters.")
            elif name in {"present_allergens", "assessed_allergens", "excluded_allergens", "accepted_holding"}:
                if not isinstance(value, list) or len(value) > 50 or any(not isinstance(x, str) or not x.strip() or len(x) > 80 for x in value):
                    raise ValueError(name + " needs an array of short labels.")
            elif name in {"handling_accepted", "agree"} and type(value) is not bool:
                raise ValueError(name + " must be true or false.")
        if action == "record_disposition" and item["outcome"] not in {"lost", "discarded", "returned_to_kitchen", "rejected_at_site"}:
            raise ValueError("Choose lost, discarded, returned_to_kitchen, or rejected_at_site.")
        if action == "save_site":
            from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
            try:
                ZoneInfo(item["time_zone"])
            except (ZoneInfoNotFoundError, ValueError):
                raise ValueError("Use a valid IANA time zone, such as Europe/London.") from None
        if action in {"create_offer", "create_need", "update_need"}:
            if item["unit"] != "meal_box" or int(item["quantity"]) < (0 if action == "update_need" else 1):
                raise ValueError("This release accepts positive whole meal boxes only; no unit conversion is applied.")
        allowed = {"chilled", "hot", "ambient"}
        if action in {"create_offer", "confirm_food"}:
            if item["holding"] is not None and item["holding"] not in allowed:
                raise ValueError("Choose chilled, hot, or ambient holding.")
            if not {x.strip().casefold() for x in item["present_allergens"]} <= {x.strip().casefold() for x in item["assessed_allergens"]}:
                raise ValueError("Every present allergen needs an assessment.")
        if action in {"create_need", "update_need"} and not set(item["accepted_holding"]) <= allowed:
            raise ValueError("Unknown receiving handling condition.")
        for field in {"present_allergens", "assessed_allergens", "excluded_allergens", "accepted_holding"} & item.keys():
            item[field] = sorted({label.strip().casefold() for label in item[field]})
        for field in {"packaging", "entrance", "contact_phone"} & item.keys():
            item[field] = item[field].strip()
        return json.dumps(item, sort_keys=True, separators=(",", ":"))
    try:
        return json.dumps({"ok": True, "payload": json.loads(normalize())})
    except (ValueError, TypeError, KeyError, OverflowError) as error:
        return json.dumps({"ok": False, "message": str(error)})
}

ClassMethod ProjectStock(declarationJSON As %String, countJSON As %String, custodyJSON As %String) As %String [ Language = python ]
{
    import json
    from allfedo.inventory import project_stock
    return json.dumps(project_stock(json.loads(declarationJSON), json.loads(countJSON), json.loads(custodyJSON)))
}

ClassMethod AtOrBefore(left As %String, right As %String) As %Boolean [ Language = python ]
{
    from datetime import datetime
    return datetime.fromisoformat(left.replace("Z", "+00:00")) <= datetime.fromisoformat(right.replace("Z", "+00:00"))
}

}
