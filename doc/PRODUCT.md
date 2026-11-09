# Allfedo: the food-rescue journey

Allfedo serves known kitchens and receiving teams, with a coordinator and approved collectors. Its signed-in workflow and recovery paths run on the contest runtime. There have been no partner interviews or physical rescue trials.

## Start with the situation

A kitchen has extra food, a counted quantity and limited collection time. A shelter knows today's need, receiving hours and food-handling ability. Someone must connect these facts to a real commitment and a person who will move the food.

The failure we target is practical: “We could take some” gets mistaken for a confirmed pickup. Food waits at the kitchen because each person assumes another arranged collection. This is our product hypothesis, not a reported interview finding.

Allfedo follows four different people:

| Person | Their responsibility |
|---|---|
| Kitchen contact | Confirm food and pickup details; record what physically leaves or returns. |
| Receiving contact | Confirm today's total need and requirements; accept food and count what arrives. |
| Collector | Agree to an assigned load, destination and times; report physical problems. |
| Coordinator | Review invitations, arrange missing commitments and handle changes. |

People receiving meals need no accounts. We do not collect their names or personal circumstances.

## Before offering food

Contacts belong to a known local network. Every account has an organization and role. This release provides private fictional accounts for local demonstrations; public signup and a partner-administration screen are outside its scope.

Kitchen and receiving contacts confirm their place, entrance, phone and time zone. The person confirming today's food or need can differ from the site's access contact. Show the relevant person where their responsibility matters.

A receiving team records its **total need for a specific window**, including amounts already promised. It confirms when receiving starts and ends, permitted holding conditions, excluded allergens and how long those details stay current. Updating today's need must not accidentally create an additional copy.

A kitchen records one food lot: whole meal boxes with the same description, holding facts, deadlines and packaging. It states allergens known present and allergens checked absent. Unchecked means unknown. Staff collection availability and the food-handling deadline are separate facts.

The app does not convert trays to boxes, certify condition, infer vehicle fit or calculate driving time. The operating network still needs its own approved handling and escalation procedures.

## From food offer to actual receipt

1. **Kitchen posts current facts.** The result is an offer, with no pickup yet. It can remain waiting for missing details rather than inventing them.
2. **Coordinator reviews a suggested split.** The native AI Hub agent reads the authorized food, current receiving needs and source evidence. It proposes invitations or returns a concrete question. The coordinator can also prepare a checked manual split.
3. **Coordinator sends separately.** Current stock and shared receiving need are rechecked together. Sending saves temporary holds and addressed invitations, each with a reply deadline. Suggesting a plan alone holds nothing.
4. **Receiving team accepts an exact quantity.** It can accept fewer boxes or decline. Unaccepted quantities are released. Its reserved food reduces what the same receiving window can still accept from every kitchen.
5. **An approved collector is assigned and agrees.** A coordinator or receiving partner assigns the person. Only that collector confirms carrying capacity, handling, pickup and arrival. Assignment alone is not a confirmed trip.
6. **Kitchen records the physical handoff.** The collector's ticket shows agreed food, load, entrances, contacts and times. A planned pickup does not move food in the records. The kitchen records what actually changed hands.
7. **Receiving staff records the accepted count.** Only that amount becomes received food. A smaller count creates specific follow-up; the app does not infer that missing boxes returned to the kitchen.

The interface shows the next responsible person before expandable facts and history. Small drawings explain collected, accepted and unresolved quantities. The same meaning must hold on a phone.

## When the counts differ

A tested fictional journey invited 35 boxes, accepted 30, handed over 28 and received 27. That means two promised boxes never left the kitchen, and one handed-over box was not accepted. It does not mean that all three have the same location or outcome.

The receiving contact later confirmed the one rejected box remained at its site. The kitchen counted 12 boxes still physically there. The coordinator proposed changing the promise from 30 to 27; the receiving contact confirmed its full current need, and the kitchen confirmed the current count. Only then did the smaller promise apply.

The original 30-box promise remains in history. Received food stays 27; the rejected box stays a separate outcome. The two unhanded boxes can be released from that promise without recreating collected stock.

Replacement demand needs its own confirmation. If 20 boxes were promised, 18 accepted and two lost, the recipient may still need 20 in total or may now need only 18. The app asks. Loss alone never chooses the answer.

## Recover without rewriting reality

| Situation | What the app must preserve and do |
|---|---|
| A recipient does not reply | Show the pending reply and exact expiry. Release only an unaccepted invitation. |
| Two kitchens compete for one need | Check shared remaining capacity in the saved transaction; reject the stale quantity. |
| Food or instructions change | Keep the agreed ticket separate from current facts. Require the relevant consent and a fresh collector agreement. |
| Kitchen reports fewer boxes | Keep the original declaration and actual count. Pause unsupported invitations; agree changes to existing promises. |
| Someone reports a handoff late | Use its physical occurrence time. Do not subtract it twice if a later kitchen count already included it. |
| A receipt arrives before its handoff report | Preserve the actual receiving report and flag the unmatched history. Do not invent a kitchen handoff. |
| Food was returned | Kitchen confirms actual return. Keep it quarantined rather than available for another invitation. |
| A count or time was wrong | The responsible party appends a correction. Keep the earlier source and pause affected replacement capacity. |
| A request's reply was lost | Keep its request identity through reload and recover the saved outcome before a new intention. |
| Model access fails | Show the failed attempt. Let the coordinator make a manual plan through the same checks. |
| Email fails | Show delivery state and current contact instructions. Mail-server acceptance is not consent. |
| The agreed destination is unavailable | Collector confirms the current count, location and holding. A new destination needs its own acceptance and collector agreement; no second kitchen pickup is invented. |

A reported physical event can remain true even when it violated an agreement. Record the event with the mismatch; do not turn that report into permission for a future unsafe action.

Known dispositions describe distinct portions of food. A linked report follows already-rejected boxes through a return to the kitchen or disposal at the receiving site. The original rejection remains visible; moving those boxes does not create another deduction or accepted meal. A contradictory excess report is retained for review instead of taking food from another portion.

An onward trip also keeps the whole carried load visible. If a collector carries 18 boxes and one new partner accepts 15, their confirmation must account for all 18. The other three still need their own outcome. The original recipient's replacement need stays paused until that team confirms it; silence does not create demand.

## Communication and practical limits

The app is the shared case record. Local demonstrations send actual SMTP email into Mailpit, a test inbox. Emails link to the signed-in case and show relevant deadlines. No real shelter delivery or live partner messaging is claimed.

Existing phone procedures remain the fallback when people cannot reach the service. Current browser input and an unfinished request reference help recover a lost response; they do not provide guaranteed offline reservations or a second stock ledger.

The first release deliberately covers whole meal boxes, known partners and human-confirmed transport. Bulk-unit conversion, a public driver marketplace, route optimization and automatic safety certification are outside its scope. Receipt is evidence of accepted food, not a count of people fed.

## What informed this design

[Feeding Charlotte's recipient process](https://feedingcharlotte.org/become-a-recipient/) informed named contacts, receiving staff and capacity confirmation. [Food Rescue Hero intake](https://admin.foodrescuehero.org/donations/intake/hunger_network) informed availability, packaging, quantity and handling questions; its [collection tracking explanation](https://foodrescuehero.org/introducing-multi-stop-rescues/) informed separate pickup and drop-off records.

[Delhivery](https://www.delhivery.com/) and [Porter](https://porter.in/trucks/delhi), suggested by the user, informed practical service explanations and useful drawings beside choices. We did not copy their business models, assume their internal dispatch design or reuse application code.

These references are not adopted local handling rules. The workflow, interface and original code belong to Allfedo. [WALKTHROUGH.md](WALKTHROUGH.md) gives concrete use and recording steps; [TECHNICAL_PLAN.md](TECHNICAL_PLAN.md) explains the actual implementation.
