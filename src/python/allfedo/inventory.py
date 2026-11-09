"""Project verified meal-box counts and custody facts without changing storage.

The native caller owns identity, source verification, locks, and food handling.
Returned food stays in quarantine; this module never makes it available again.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from itertools import groupby
import re


@dataclass(frozen=True)
class _Fact:
    at: datetime
    source: int
    quantity: int
    kind: str


def _amount(value: object, field: str) -> int:
    if not isinstance(value, str) or len(value) > 40 or not re.fullmatch(r"[0-9]+(?:\.0+)?", value):
        raise ValueError(f"{field} must be a nonnegative whole meal-box quantity string.")
    return int(value.split(".", 1)[0])


def _instant(value: object, field: str) -> datetime:
    if not isinstance(value, str):
        raise ValueError(f"{field} needs a date, time, and UTC offset.")
    try:
        instant = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if instant.utcoffset() is None:
            raise ValueError("missing UTC offset")
        return instant.astimezone(timezone.utc)
    except (ValueError, OverflowError):
        raise ValueError(f"{field} needs a date, time, and UTC offset.") from None


def _fact(record: object, kind: str, field: str) -> _Fact:
    if not isinstance(record, dict) or record.get("unit", "meal_box") != "meal_box":
        raise ValueError(f"{field} must be a meal-box fact record.")
    source = record.get("source_id")
    if not isinstance(source, str) or not re.fullmatch(r"[1-9][0-9]{0,18}", source):
        raise ValueError(f"{field}.source_id must be a positive numeric IRIS source ID.")
    quantity = "on_hand_quantity" if kind == "count" else "quantity"
    return _Fact(_instant(record.get("occurred_at"), field + ".occurred_at"), int(source),
                 _amount(record.get(quantity), field + "." + quantity), kind)


def project_stock(declaration: dict, count: dict | None, custody: list[dict]) -> dict:
    """Return a JSON-safe current projection or pause it for concrete review.

    Declaration: quantity, unit='meal_box', source_id, occurred_at. Optional
    legacy_collected_quantity defaults to '0'. A nonzero legacy amount requires
    legacy_recorded_until: its observed upper time bound, never an invented
    handoff time. Count: on_hand_quantity, source_id, occurred_at, or None.
    Custody: kind, quantity, source_id, occurred_at. Kinds are handoff, returned,
    and quarantine_disposed. Optional per-record units must match meal_box.

    A count includes every physical box, including quarantine. Earlier facts
    are already reflected in it. A nonzero custody fact at the count's exact
    stated time has unknown physical order and requires a later fresh count.
    Equal-time custody totals are checked together, without inventing their
    internal order. Source IDs must be unique and only order issue reporting.
    Neither source IDs nor input order prove inclusion in a physical count.

    Shape errors raise ValueError; callers must stop without replacing stored
    balances. Contradictory/ambiguous facts return review_required and usable0.
    Unknown totals are null, so native storage can retain its prior total.
    """
    if not isinstance(declaration, dict) or declaration.get("unit") != "meal_box":
        raise ValueError("The declaration must explicitly use meal_box.")
    initial = _fact(declaration, "declaration", "declaration")
    observed = _fact(count, "count", "count") if count is not None else None
    legacy = _amount(declaration.get("legacy_collected_quantity", "0"), "legacy_collected_quantity")
    legacy_bound = declaration.get("legacy_recorded_until")
    if legacy or legacy_bound is not None:
        legacy_bound = _instant(legacy_bound, "legacy_recorded_until")
    if not isinstance(custody, list):
        raise ValueError("custody must be an array of verified physical facts.")
    entries = []
    for index, item in enumerate(custody):
        kind = item.get("kind") if isinstance(item, dict) else None
        if kind not in ("handoff", "returned", "quarantine_disposed"):
            raise ValueError("Each custody fact needs a supported kind.")
        entries.append(_fact(item, kind, f"custody[{index}]"))
    sources = [initial.source] + ([observed.source] if observed else []) + [item.source for item in entries]
    if len(sources) != len(set(sources)):
        raise ValueError("A source ID must appear only once in the stock evidence.")
    entries.sort(key=lambda item: (item.at, item.source))
    collected = legacy + sum(item.quantity for item in entries if item.kind == "handoff")
    issues = []

    def issue(code: str, message: str, source: int):
        issues.append({"code": code, "message": message, "source_id": str(source)})

    known_handoffs, returned, quarantine = legacy, 0, 0
    quarantine_known = True
    for _, same_time in groupby(entries, key=lambda item: item.at):
        group = list(same_time)
        for item in group:
            if item.kind == "handoff":
                known_handoffs += item.quantity
            elif item.kind == "returned":
                returned += item.quantity
                quarantine += item.quantity
            else:
                quarantine -= item.quantity
        # This source identifies the equal-time group, not its physical order.
        group_source = group[0].source
        if returned > known_handoffs:
            quarantine_known = False
            issue("RETURN_EXCEEDS_HANDOFF", "Returned food exceeds handoffs through this stated time.", group_source)
        if quarantine < 0:
            quarantine_known = False
            issue("DISPOSAL_EXCEEDS_QUARANTINE", "Disposed food exceeds quarantine through this stated time.", group_source)

    current_total = initial.quantity
    if observed is None:
        for item in entries:
            if item.quantity and item.at < initial.at:
                issue("FACT_PRECEDES_DECLARATION", "A physical fact predates the first lot declaration; confirm the current count.", item.source)
    else:
        if observed.at < initial.at:
            issue("COUNT_PRECEDES_DECLARATION", "This count predates the first declaration and cannot replace it.", observed.source)
        if legacy and observed.at < legacy_bound:
            issue("COUNT_PRECEDES_LEGACY_BOUND", "Older handoff times are unknown at this count; record a current count.", observed.source)
        before = [item for item in entries if item.at < observed.at]
        for item in entries:
            if item.quantity and item.at == observed.at:
                issue("AMBIGUOUS_COUNT_TIME", "Physical order is unknown at this count's stated time; confirm a count at a later time.", item.source)
        quarantined_before = sum(item.quantity for item in before if item.kind == "returned") - sum(item.quantity for item in before if item.kind == "quarantine_disposed")
        if quarantined_before > observed.quantity:
            issue("COUNT_BELOW_QUARANTINE", "The physical count is smaller than the quarantine it must include.", observed.source)
        usable_at_count = observed.quantity - quarantined_before
        current_total = usable_at_count + legacy + sum(item.quantity for item in before if item.kind == "handoff")
    usable = current_total - collected
    if usable < 0:
        issue("HANDOFF_EXCEEDS_STOCK", "Recorded handoffs exceed the stock established by the latest evidence.", observed.source if observed else initial.source)
    review = bool(issues)
    return {"unit": "meal_box", "current_total_quantity": None if review else str(current_total),
            "collected_quantity": str(collected),
            "quarantined_quantity": str(quarantine) if quarantine_known else None,
            "usable_on_hand_quantity": "0" if review else str(usable),
            "review_required": review, "issues": issues}
