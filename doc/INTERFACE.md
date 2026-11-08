# Allfedo: experience brief

The first sketch's visual design was rejected. Its one-off simulation is not the foundation for the app. Keep the useful agreement flow in [PRODUCT.md](PRODUCT.md); build the real states described in [TECHNICAL_PLAN.md](TECHNICAL_PLAN.md).

## What each person should understand

Every work item must show the food and unit, relevant quantity, location, time window, responsible person, current uncertainty, and next action. A person should not need the original pitch to understand the screen.

| Person | Their starting view | Main work |
|---|---|---|
| Kitchen contact | Today's offers and expected collections | Offer food; see who agreed to collect; report changes; record handoffs. |
| Shelter contact | Addressed offers, expected arrivals, and today's need | Confirm capacity; accept a specific collection; ask for help; confirm receipt. |
| Collector | Assigned collections | Find entrances and contacts; see packaging and destinations; report a problem. |
| Coordinator | Cases needing a decision, then upcoming collections | Compare feasible recipients, arrange missing commitments, resolve changes and discrepancies. |

Contacts belong to organization/site profiles. Use realistic international placeholders during development. Today's capacity and transport agreements show when and by whom they were confirmed.

## Design for a working day

The coordinator handles several kitchens, overlapping offers, competing needs, delayed replies, and collectors with existing assignments. One row is a real case or collection, not a fixed column in a demonstration.

Start with an action list. State the obstacle and needed decision: **10 boxes short — Alex Morgan needs revised quantities confirmed**, or **Bridge's invitation was not delivered — contact Sam Reed before the hold ends**.

Separate a new decision from waiting on someone else. A confirmed collection should not keep asking the coordinator to arrange it. An older source message stays in history, not as the current warning.

Filter by location, organization, responsible person, and time window. Opening a case retains the list context so handling an exception does not make the coordinator lose their place.

## Make commitments visible

- Carry the same offer, lot, recipient, and collection identity across related views.
- Label quantity precisely: **35 held**, **35 collected**, **33 accepted**, **2 awaiting explanation**. Do not make people reconstruct the difference.
- Use a time-window strip for ready time, collection deadline, agreed pickups, and receiving deadline. Pair visual markers with readable times.
- Describe packaging physically: **35 boxes in 7 carry cartons**, with the collector's capacity agreement beside it.
- Show changed facts with the previous and current value, source, and affected commitments.
- Explain a proposal through actual needs and messages. Keep evidence one step away.

These cues encode real work. They are not decorative progress bars or impact counters.

## Forms serve the situation

Saved site and contact details reduce repeated entry. Routine offers should be quick. Additional questions appear because that food or collection needs them, not because every case shares an arbitrary three-field form.

Keep original units. Do not silently convert trays or kilograms into meal boxes. Unknown ingredients, holding information, capacity, or receiving hours need an answer or review.

Before acceptance, show the exact quantity/unit, food facts, collection window, collector, destination, and receiving deadline. Changing quantity changes the acceptance button's wording.

Contact and directions actions use verified details. Escalation leads to a specific person and task. Avoid buttons that merely display reassurance without changing the relevant work.

## Feedback matches saved outcomes

| Situation | Useful wording |
|---|---|
| Invitation exists | **35 boxes held for Riverside until 6:05 PM. Waiting for Jamie Taylor's reply.** |
| Transport is tentative | **Jamie Taylor has not confirmed a collector. Ask before promising collection.** |
| Acceptance is in flight | **Sending acceptance. Your pickup is not confirmed yet.** |
| Reply was lost | **Checking whether your acceptance was saved.** |
| Capacity changed | **Riverside can now accept 15 more boxes. Review the quantity.** |
| Receipt is short | **33 boxes accepted. Jordan Lee is following up on the other 2.** |

Use observed facts. A sent email is not a read invitation. A timer ending is not proof that a confirmed collector never arrived. A stale approval needs a current decision.

## Develop a new visual direction

Compare at least two compositions using the same realistic working-day data: a task-first workbench and a collection schedule with visible dependencies. Judge finding the next action, understanding a changed commitment, and using the pickup ticket on a phone.

Choose typography, spacing, hierarchy, and color deliberately. Use meaningful status color, clear units, strong keyboard focus, and readable touch targets. The discarded palette and card arrangement are not approved defaults.

The useful visual signature comes from physical quantities, time windows, and named commitments. It should not depend on generic AI motifs or decorative cards.

## Review before treating a screen as ready

Walk through offers competing for one need, an unavailable collector, a kitchen shortfall, stale review, an undelivered invitation, a late pickup, and a partial receipt. Follow each action to its saved state, next owner, and physical consequence.

Inspect desktop/mobile views, keyboard interaction, long names, incomplete data, and conflicting deadlines. Use backend states as soon as available. A screenshot or click test alone does not establish an operational product.
