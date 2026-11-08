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
            "create_offer": {"description", "quantity", "unit", "ready_at", "collect_by", "holding", "present_allergens", "assessed_allergens", "event_at"},
            "create_need": {"quantity", "unit", "receiving_until", "confirmed_until", "excluded_allergens", "accepted_holding", "event_at"},
            "apply_plan": {"offer_id", "offer_revision", "requests", "reason"},
            "accept": {"allocation_id", "revision", "quantity"},
            "decline": {"allocation_id", "revision", "reason"},
            "assign_collector": {"allocation_id", "revision", "collector_actor_id"},
            "confirm_transport": {"allocation_id", "revision", "pickup_at", "arrival_by", "capacity", "handling_accepted"},
            "handoff": {"allocation_id", "revision", "quantity", "note"},
            "receive": {"allocation_id", "revision", "quantity", "note"},
            "observe_stock": {"offer_id", "revision", "quantity", "note"},
            "expire_hold": {"allocation_id", "revision"},
        }
        if action not in fields:
            raise ValueError("Unknown command action.")
        item = json.loads(payload)
        if not isinstance(item, dict) or set(item) != fields[action]:
            raise ValueError("Supply exactly the documented fields for " + action + ".")
        for name, value in item.items():
            if name in {"ready_at", "collect_by", "receiving_until", "confirmed_until", "event_at", "pickup_at", "arrival_by"}:
                from datetime import datetime
                try:
                    instant = datetime.fromisoformat(value.replace("Z", "+00:00"))
                    if instant.utcoffset() is None:
                        raise ValueError("missing offset")
                except (AttributeError, TypeError, ValueError, OverflowError):
                    raise ValueError(name + " needs a full date, time, and UTC offset.") from None
            elif name in {"quantity", "capacity"}:
                if not isinstance(value, str) or not re.fullmatch(r"[0-9]{1,6}", value):
                    raise ValueError(name + " must be a whole-number string, at most 999999.")
            elif name in {"revision", "offer_revision"}:
                if type(value) is not int or value < 1:
                    raise ValueError(name + " must be a positive integer.")
            elif name.endswith("_id") or name in {"description", "reason", "unit", "holding"}:
                if not isinstance(value, str) or not value.strip() or len(value) > 500:
                    raise ValueError(name + " needs nonempty text, at most 500 characters.")
            elif name == "note":
                if not isinstance(value, str) or len(value) > 2000:
                    raise ValueError("A note must be text, at most 2000 characters.")
            elif name in {"present_allergens", "assessed_allergens", "excluded_allergens", "accepted_holding"}:
                if not isinstance(value, list) or len(value) > 50 or any(not isinstance(x, str) or not x.strip() or len(x) > 80 for x in value):
                    raise ValueError(name + " needs an array of short labels.")
            elif name == "handling_accepted" and type(value) is not bool:
                raise ValueError("handling_accepted must be true or false.")
        if action in {"create_offer", "create_need"}:
            if item["unit"] != "meal_box" or int(item["quantity"]) < 1:
                raise ValueError("This release accepts positive whole meal boxes only; no unit conversion is applied.")
            allowed = {"chilled", "hot", "ambient"}
            if action == "create_offer":
                if item["holding"] not in allowed:
                    raise ValueError("Choose chilled, hot, or ambient holding.")
                if not set(item["present_allergens"]) <= set(item["assessed_allergens"]):
                    raise ValueError("Every present allergen needs an assessment.")
            elif not set(item["accepted_holding"]) <= allowed:
                raise ValueError("Unknown receiving handling condition.")
        return json.dumps(item, sort_keys=True, separators=(",", ":"))
    try:
        return json.dumps({"ok": True, "payload": json.loads(normalize())})
    except (ValueError, TypeError, KeyError, OverflowError) as error:
        return json.dumps({"ok": False, "message": str(error)})
}
}
