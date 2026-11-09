# Try Allfedo and record the demo

Use fictional food and partners. This walkthrough checks software behavior; it does not establish food condition or a real delivery.

## Prepare once

Follow the [installation steps](../README.md), then run:

```bash
python3 scripts/demo.py
```

Open `.env.demo.json` privately. It contains six accounts with random passwords. Keep that file, login screens, terminal environments and browser developer tools out of the recording.

Use four separate browser profiles, each signed into <http://127.0.0.1:52773/allfedo/>. Ordinary tabs share a login; they do not create separate people.

| Profile | Account in the private file | Responsibility |
|---|---|---|
| Kitchen | `northside` | Confirm food and record what leaves. |
| Receiving | `riverside` | Confirm today's need, accept an invitation and count arrivals. |
| Coordinator | `coordinator` | Review the proposed split, send invitations and handle problems. |
| Collector | `collector` | Agree to their assigned load, route and times. |

`harbor` is a second kitchen; `bridge` is a second receiving team. Use them when showing competition for the same remaining need or a split across partners.

The demo locations are explicitly fictional. Check each partner's saved location, entrance, phone and time zone. Use times relative to the current site clock; yesterday's sample times will correctly fail.

## One case from offer to receipt

1. **Receiving:** record a total need of 30 meal boxes for a current receiving window. Confirm chilled-food handling. If excluding peanut, the kitchen must explicitly confirm it checked peanut and found none. An unchecked allergen is unknown. Update a matching existing window rather than adding the same demand twice.
2. **Kitchen:** offer 40 sealed vegetable-rice meal boxes. Choose chilled holding, confirm its deadline, and describe the load: eight carry cartons of five boxes. Set food ready now, collection ending in an hour, and a handling deadline that covers the intended arrival. Record milk as present and peanut as checked absent. Confirm only facts the kitchen can actually know.
3. **Coordinator:** open that food offer and its invitation plan. Ask the agent for a suggestion. This uses the configured OpenAI key and incurs provider usage. Explain the saved suggestion and its supporting current facts. Quantities may vary; do not present a rehearsed number as a guaranteed model response.
4. **Coordinator:** check the plan, then send it in a separate action. Before sending, no food is held. After sending, the receiving team has an invitation and an exact reply deadline. Open <http://127.0.0.1:8025> to show the local test email. This is a test inbox, not a message to a real shelter.
5. **Receiving:** accept the offered quantity, or a smaller quantity. The accepted amount is reserved; the rest is released. Assign the approved collector. Assignment alone does not confirm their trip.
6. **Collector:** open the assigned ticket. Read the load, entrances, contacts and deadlines. Confirm a feasible pickup and arrival, carrying capacity and handling. The app does not calculate driving time; this is the collector's explicit commitment.
7. **Kitchen:** when demonstrating the physical handoff, record the actual number given to that named collector. Say that the physical action is simulated for the demonstration. A planned time alone must never change the collection count.
8. **Receiving:** record the actual accepted count. A matching count completes the collection. A smaller count leaves a named follow-up; the app does not quietly turn missing boxes back into available stock.

For a no-cost rehearsal, prepare the plan manually instead of calling the agent. Clearly identify which version you show. A manual plan passing the same checks is the fallback when a model is unavailable, not proof that an agent ran.

## Show a changed destination

Use a second case rather than editing the completed one. Confirm Bridge Centre's current need and receiving window first.

1. Agree 20 boxes for Riverside and record an actual simulated handoff of 18. The two uncollected boxes remain a separate kitchen responsibility.
2. As collector, open **Receiving point unavailable? Report the food still with you**. Confirm 18 boxes, the current location, occurrence time and holding conditions. Do not infer those facts from the old ticket.
3. As coordinator, use **Find another receiving point**. Review Bridge's current need, offer 15 carried boxes and use **Send onward food invitation**.
4. As Bridge, review and accept the exact quantity. As collector, open the linked collection, agree the new destination and arrival, and confirm capacity for the whole 18 still carried. A 15-box destination does not make the other three disappear.
5. As Bridge, record 15 accepted boxes when demonstrating arrival. Handle the remaining three through a fresh collector report and another accepted invitation, or record their actual known outcome. Do not record another kitchen handoff.

The original case and linked destination remain identifiable. Riverside's silence must not create replacement demand. A report that holding conditions broke blocks automatic onward agreement; do not manufacture a successful redirection by clearing that report.

## Show what happens to rejected food

In another small case, hand over four boxes and record two accepted. Use **Record a known outcome for food not accepted** to report two rejected boxes still held at the receiving site.

Open **Physical reports and corrections**. The kitchen can record an actual later return of one rejected box; the receiving team can record disposal of the other. Link each movement to the existing rejection. Accepted food stays two, and the rejected portion is accounted for once. A kitchen return stays in quarantine; **Record quarantine disposal** does not create usable food.

Use fictional events throughout. These steps demonstrate recorded responsibility; they are not instructions for deciding whether real food is safe to move or dispose of.

## A short video story

Aim for about five minutes. Show decisions and changed outcomes, rather than every field.

| Time | Show | Explain |
|---|---|---|
| 0:00–0:30 | A real kitchen offer and current receiving need. | “Extra food needs a real agreement, a named collector and a receiving count.” |
| 0:30–1:30 | Agent suggestion, check and separate send. | The agent proposes a useful split; current shared quantities and food facts are checked before a hold is saved. |
| 1:30–2:30 | Receiving acceptance, collector assignment and their own trip confirmation. | Three different responsibilities stay separate. A notification is not consent. |
| 2:30–3:30 | Kitchen handoff and receiving count. | Actual quantities replace assumptions about what moved. |
| 3:30–4:30 | A second case with a short count or changed instructions. | Show the exact next action and whose response is needed. Show a resolution only after its real checks pass. |
| 4:30–5:00 | Saved case evidence and repository setup. | IRIS runs the workflow and keeps the commitments; Embedded Python checks proposals and physical stock. State the demo and deployment limits. |

Keep the cursor slow. Use readable zoom and an uncluttered desktop. Cut login transitions. Do not narrate a success that the screen has not confirmed. If the model needs time, show its actual saved result and label any edit in the recording.

Export a normal MP4. For the video bonus, supply a download link that works without signing in, as well as any watch link. Verify both links in a signed-out browser before adding them to the listing. Recording and publication belong to the participant.

The initial entry can use the written app description. Improvements are allowed during voting, so the video can be added afterward. Add its accessible download link before voting closes on **15 November 2026 at 11:59 PM EST**, and allow time for the organizers to check it. [Contest announcement](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows), [video conditions](https://community.intersystems.com/post/technology-bonuses-intersystems-programming-contest-ai-agents-interoperability-workflows).

## Human checks before publishing

These are checks for the participant to perform; they are not claimed as completed manual testing.

- Use a narrow phone screen. Can a new person find their next action and the partner contact without an explanation?
- Read the invitation as the receiving contact. Is the quantity, deadline, food, load and commitment understandable before accepting?
- Change the pickup entrance after a trip was agreed. The earlier ticket must remain identifiable, and the new details must require confirmation.
- Report fewer boxes at the kitchen. Existing promises must remain visible; missing stock must not support another invitation.
- Accept fewer boxes than were collected. The accepted count must stay separate from the unresolved outcome and any replacement need.
- Disconnect after pressing a save action, then reload. Use the recovery notice to check the same request. Confirm that a second offer, hold or physical report was not created.
- Sign in as another partner. Direct links must not reveal another organization's case or a collector's unassigned pickup.
- Check email failures and contact instructions. A sent email must not be described as read, accepted or delivered food.

Keep brief notes with the build/commit, screen size, steps, expected outcome and observed outcome. Fix failures before recording. Never use real partner details or real food movement merely to make a software demonstration look realistic.
