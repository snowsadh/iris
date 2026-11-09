"""Validate invitation proposals against current, trusted case records.

This module does not reserve food, confirm transport, or authorize a caller.
The native transaction must fetch the current shared stock/need records and
validate again before committing holds. Source facts supplied here must already
belong to the authorized case; raw model extraction is not confirmed evidence.
"""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
import re


_UNIT_SCALE = {"meal_box": 0, "tray": 0, "kg": 3}
_HOLDING = {"chilled", "hot", "ambient"}
_CONFIRMATIONS = (
    "recipient_acceptance",
    "named_collector",
    "pickup_time",
    "transport_capacity",
    "food_handling_acceptance",
)


class _Rejected(ValueError):
    def __init__(self, code: str, message: str, need_id: str | None = None):
        super().__init__(message)
        self.code = code
        self.need_id = need_id


def _text(value: object, field: str, *, snapshot: bool = False) -> str:
    if not isinstance(value, str) or not value.strip() or len(value) > 1000:
        raise _Rejected("INVALID_SNAPSHOT" if snapshot else "INVALID_PROPOSAL",
                        f"{field} must be nonempty text of at most 1000 characters.")
    return value.strip()


def _revision(value: object, field: str, *, snapshot: bool = False) -> int:
    if type(value) is not int or value < 1:
        raise _Rejected("INVALID_SNAPSHOT" if snapshot else "INVALID_PROPOSAL",
                        f"{field} must be a positive integer revision.")
    return value


def _instant(value: object, field: str) -> datetime:
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if result.utcoffset() is None:
            raise ValueError("missing time zone")
        return result.astimezone(timezone.utc)
    except (AttributeError, TypeError, ValueError, OverflowError):
        raise _Rejected("INVALID_SNAPSHOT", f"{field} needs a full date, time, and UTC offset.") from None


def _strings(value: object, field: str, *, snapshot: bool = False) -> set[str]:
    if not isinstance(value, list):
        raise _Rejected("INVALID_SNAPSHOT" if snapshot else "INVALID_PROPOSAL",
                        f"{field} must be an array of strings.")
    return {_text(item, field, snapshot=snapshot) for item in value}


def _quantity(value: object, unit: str, field: str, *, snapshot: bool = False) -> Decimal:
    code = "INVALID_SNAPSHOT" if snapshot else "INVALID_QUANTITY"
    if not isinstance(value, str) or not re.fullmatch(r"[0-9]{1,15}(?:\.[0-9]{1,3})?", value):
        raise _Rejected(code, f"{field} must be a nonnegative decimal string with at most three decimal places.")
    amount = Decimal(value)
    if unit in _UNIT_SCALE and _UNIT_SCALE[unit] == 0 and amount != amount.to_integral_value():
        raise _Rejected(code, f"{field} must count whole {unit} units.")
    return amount


def _read_snapshot(snapshot: dict) -> tuple[datetime, dict, dict[str, dict], set[str]]:
    network_id = _text(snapshot["network_id"], "network_id", snapshot=True)
    now = _instant(snapshot["now"], "now")
    offer = snapshot["offer"]
    if not isinstance(offer, dict):
        raise _Rejected("INVALID_SNAPSHOT", "offer must be a record.")
    offer = dict(offer)
    offer["id"] = _text(offer["id"], "offer.id", snapshot=True)
    offer["revision"] = _revision(offer["revision"], "offer.revision", snapshot=True)
    offer["state"] = _text(offer["state"], "offer.state", snapshot=True)
    if offer["network_id"] != network_id:
        raise _Rejected("INVALID_SNAPSHOT", "The offer belongs to a different network.")
    offer["unit"] = _text(offer["unit"], "offer.unit", snapshot=True)
    offer["available_quantity"] = _quantity(offer["available_quantity"], offer["unit"], "offer.available_quantity", snapshot=True)
    offer["ready_at"] = _instant(offer["ready_at"], "offer.ready_at")
    offer["collect_by"] = _instant(offer["collect_by"], "offer.collect_by")
    if offer["handling_until"] is not None:
        offer["handling_until"] = _instant(offer["handling_until"], "offer.handling_until")
    if offer["ready_at"] >= offer["collect_by"]:
        raise _Rejected("INVALID_SNAPSHOT", "The food must be ready before collection closes.")
    offer["source_ids"] = _strings(offer["source_ids"], "offer.source_ids", snapshot=True)
    if not offer["source_ids"]:
        raise _Rejected("INVALID_SNAPSHOT", "The offer needs source evidence.")
    offer["present_allergens"] = {tag.casefold() for tag in _strings(offer["present_allergens"], "offer.present_allergens", snapshot=True)}
    offer["assessed_allergens"] = {tag.casefold() for tag in _strings(offer["assessed_allergens"], "offer.assessed_allergens", snapshot=True)}
    if not offer["present_allergens"] <= offer["assessed_allergens"]:
        raise _Rejected("INVALID_SNAPSHOT", "Present allergens must have recorded assessments.")
    if offer["holding"] is not None and offer["holding"] not in _HOLDING:
        raise _Rejected("INVALID_SNAPSHOT", "The offer has an unknown holding value.")
    automatic_units = _strings(snapshot.get("automatic_units", ["meal_box"]), "automatic_units", snapshot=True)
    if not automatic_units <= _UNIT_SCALE.keys():
        raise _Rejected("INVALID_SNAPSHOT", "Automatic units must have an explicit quantity policy.")
    records = snapshot["needs"]
    if not isinstance(records, list):
        raise _Rejected("INVALID_SNAPSHOT", "needs must be an array of current need records.")
    needs = {}
    for item in records:
        if not isinstance(item, dict):
            raise _Rejected("INVALID_SNAPSHOT", "Each need must be a record.")
        need = dict(item)
        need_id = _text(need["id"], "need.id", snapshot=True)
        if need_id in needs or need["network_id"] != network_id:
            raise _Rejected("INVALID_SNAPSHOT", "Need IDs must be unique and belong to this network.")
        need["organization_id"] = _text(need["organization_id"], "need.organization_id", snapshot=True)
        need["revision"] = _revision(need["revision"], "need.revision", snapshot=True)
        need["state"] = _text(need["state"], "need.state", snapshot=True)
        need["unit"] = _text(need["unit"], "need.unit", snapshot=True)
        need["remaining_quantity"] = _quantity(need["remaining_quantity"], need["unit"], "need.remaining_quantity", snapshot=True)
        need["receiving_until"] = _instant(need["receiving_until"], "need.receiving_until")
        need["confirmed_until"] = _instant(need["confirmed_until"], "need.confirmed_until")
        need["source_ids"] = _strings(need["source_ids"], "need.source_ids", snapshot=True)
        if not need["source_ids"]:
            raise _Rejected("INVALID_SNAPSHOT", "Each need requires source evidence.")
        need["excluded_allergens"] = {tag.casefold() for tag in _strings(need["excluded_allergens"], "need.excluded_allergens", snapshot=True)}
        need["accepted_holding"] = _strings(need["accepted_holding"], "need.accepted_holding", snapshot=True)
        if not need["accepted_holding"] <= _HOLDING:
            raise _Rejected("INVALID_SNAPSHOT", "A need has an unknown accepted holding value.")
        needs[need_id] = need
    return now, offer, needs, automatic_units


def validate_invitation_plan(snapshot: dict, proposal: dict) -> dict:
    """Return a JSON-safe validated proposal or an explicit business rejection.

    Snapshot: network_id, now, offer, needs, and optional automatic_units.
    The offer carries current stock, revision, unit, ready_at/collect_by,
    handling_until (a confirmed deadline or null),
    source_ids, holding, present_allergens, assessed_allergens, and state.
    Each need carries current shared remaining quantity, revision, state, unit,
    receiving_until/confirmed_until, source_ids, excluded_allergens and
    accepted_holding. All timestamps include a full date and UTC offset.

    Proposal: offer_id, offer_revision, reason, and requests. Each request has
    need_id, need_revision, quantity (decimal string), unit, and evidence_ids.
    A successful result is suitable for an invitation hold, never a confirmed
    pickup. Native persistence must revalidate under its transaction.
    """
    try:
        if not isinstance(snapshot, dict):
            raise _Rejected("INVALID_SNAPSHOT", "The trusted snapshot must be a record.")
        try:
            now, offer, needs, automatic_units = _read_snapshot(snapshot)
        except (KeyError, TypeError):
            raise _Rejected("INVALID_SNAPSHOT", "A required snapshot field is missing or malformed.") from None
        if not isinstance(proposal, dict) or set(proposal) != {"offer_id", "offer_revision", "requests", "reason"}:
            raise _Rejected("INVALID_PROPOSAL", "Use only offer_id, offer_revision, requests, and reason.")
        if proposal["offer_id"] != offer["id"]:
            raise _Rejected("WRONG_OFFER", "The proposal does not belong to this offer.")
        if _revision(proposal["offer_revision"], "offer_revision") != offer["revision"]:
            raise _Rejected("STALE_OFFER", "The food offer changed. Review the current facts before sending requests.")
        reason = _text(proposal["reason"], "reason")
        if offer["state"] != "open":
            raise _Rejected("OFFER_NOT_OPEN", "This offer is paused or closed; new requests need review.")
        if now >= offer["collect_by"]:
            raise _Rejected("OFFER_EXPIRED", "The collection window ended. No new invitation can be held.")
        if offer["unit"] not in automatic_units:
            raise _Rejected("UNIT_REQUIRES_REVIEW", "This unit needs an explicit supported handling/conversion decision.")
        if offer["holding"] is None or offer["handling_until"] is None:
            raise _Rejected("FOOD_INFORMATION_MISSING", "Ask the kitchen to confirm holding and its handling deadline before sending requests.")
        collection_end = min(offer["collect_by"], offer["handling_until"])
        if max(now, offer["ready_at"]) >= collection_end:
            raise _Rejected("FOOD_HANDLING_WINDOW_ENDED", "The confirmed food-handling window leaves no time for collection.")
        requests = proposal["requests"]
        if not isinstance(requests, list) or not requests:
            raise _Rejected("INVALID_PROPOSAL", "Provide at least one request within the current candidate needs.")
        normalized = []
        seen = set()
        total = Decimal(0)
        for request in requests:
            if not isinstance(request, dict) or set(request) != {"need_id", "need_revision", "quantity", "unit", "evidence_ids"}:
                raise _Rejected("INVALID_PROPOSAL", "Each request needs only its need, revision, quantity, unit, and evidence.")
            need_id = _text(request["need_id"], "need_id")
            if need_id not in needs:
                raise _Rejected("UNKNOWN_NEED", "This receiving need is not an authorized candidate for the case.", need_id)
            if need_id in seen:
                raise _Rejected("DUPLICATE_NEED", "Combine a receiving need into one request before validation.", need_id)
            seen.add(need_id)
            need = needs[need_id]
            if need["state"] != "open":
                raise _Rejected("NEED_REQUIRES_REVIEW", "This receiving need changed and requires review before new invitations.", need_id)
            if _revision(request["need_revision"], "need_revision") != need["revision"]:
                raise _Rejected("STALE_NEED", "The receiving need changed. Use its current remaining quantity.", need_id)
            if request["unit"] != offer["unit"] or need["unit"] != offer["unit"]:
                raise _Rejected("UNIT_MISMATCH", "Food and receiving need use different units; no conversion was applied.", need_id)
            quantity = _quantity(request["quantity"], offer["unit"], "request.quantity")
            if quantity <= 0:
                raise _Rejected("INVALID_QUANTITY", "An invitation must offer a positive quantity.", need_id)
            if now >= need["confirmed_until"]:
                raise _Rejected("NEED_CONFIRMATION_EXPIRED", "Ask the receiving partner to refresh today's need.", need_id)
            if max(now, offer["ready_at"]) >= need["receiving_until"]:
                raise _Rejected("RECEIVING_WINDOW_ENDED", "The food cannot be collected before this receiving window ends.", need_id)
            if quantity > need["remaining_quantity"]:
                raise _Rejected("NEED_CAPACITY_CHANGED", "This request exceeds the need still available across all kitchens.", need_id)
            if offer["present_allergens"] & need["excluded_allergens"]:
                raise _Rejected("FOOD_INCOMPATIBLE", "The kitchen declares an allergen this recipient excludes.", need_id)
            if not need["excluded_allergens"] <= offer["assessed_allergens"]:
                raise _Rejected("FOOD_INFORMATION_MISSING", "A required allergen assessment is missing; ask the kitchen.", need_id)
            if not need["accepted_holding"]:
                raise _Rejected("HANDLING_CAPABILITY_UNKNOWN", "Confirm the recipient can handle the declared holding condition.", need_id)
            if offer["holding"] not in need["accepted_holding"]:
                raise _Rejected("HANDLING_INCOMPATIBLE", "The recipient cannot handle this declared holding condition.", need_id)
            references = _strings(request["evidence_ids"], "evidence_ids")
            if references - (offer["source_ids"] | need["source_ids"]):
                raise _Rejected("UNKNOWN_EVIDENCE", "A cited source does not belong to this offer and receiving need.", need_id)
            if not offer["source_ids"] <= references or not need["source_ids"] <= references:
                raise _Rejected("EVIDENCE_MISSING", "Cite current food and receiving-need evidence for this request.", need_id)
            total += quantity
            if total > offer["available_quantity"]:
                raise _Rejected("INSUFFICIENT_STOCK", "The requests exceed this lot's current unassigned quantity.")
            normalized.append({
                "need_id": need_id, "need_revision": need["revision"],
                "quantity": format(quantity.normalize(), "f"), "unit": offer["unit"],
                "evidence_ids": sorted(references),
                "confirmation_requirements": list(_CONFIRMATIONS),
            })
        return {"ok": True, "plan": {"offer_id": offer["id"], "offer_revision": offer["revision"],
                                     "requests": normalized, "reason": reason}}
    except _Rejected as error:
        return {"ok": False, "error": {"code": error.code, "message": str(error), "need_id": error.need_id}}
