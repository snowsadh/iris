# Try a complete collection

Follow [setup](../README.md), then run `python3 scripts/demo.py`. Use fictional food and events. The exercise demonstrates saved software behavior, not real food condition or a physical delivery.

## Open the four roles

Use separate browser profiles or isolated browser contexts. Ordinary tabs share a login. Sign in at <http://127.0.0.1:52773/allfedo/> with credentials from your local `.env.demo.json`.

| Account key | Role |
|---|---|
| `northside` | Kitchen: confirm food and record what leaves. |
| `riverside` | Receiving team: confirm need, accept food and count arrivals. |
| `coordinator` | Coordinator: review invitations and handle changes. |
| `collector` | Collector: agree the assigned load and trip. |

`harbor` is another kitchen; `bridge` is another receiving team. Locations and contacts are fictional. Check each saved place, entrance and time zone. Use dates relative to the current site clock.

## Follow one offer

1. **Receiving team:** confirm a total need of 30 meal boxes and a receiving window. Confirm chilled-food handling. If excluding peanut, the kitchen must explicitly assess it; unchecked allergens are unknown.
2. **Kitchen:** offer 40 sealed vegetable-rice meal boxes, chilled, in eight carry cartons of five. Set a current ready time, a collection deadline and a handling deadline covering the intended arrival. Record milk as present and peanut as checked absent.
3. **Coordinator:** open the offer's invitation plan. Use **Get a planning suggestion** for a live paid agent decision, or prepare a manual split for a no-cost exercise. Review the saved facts, check the plan and use **Send these invitations** separately. A suggestion alone holds no food.
4. **Receiving team:** accept the exact offered quantity, or fewer. Assign the approved collector. Assignment does not confirm their trip.
5. **Collector:** open the ticket and confirm the load, pickup, arrival and handling. The app does not calculate driving time; the collector makes that commitment.
6. **Kitchen:** simulate the physical handoff and record the actual quantity given to the named collector.
7. **Receiving team:** simulate arrival and record the accepted count. A matching count completes the collection; a smaller count leaves specific follow-up.

Open the [local test inbox](http://127.0.0.1:8025) to inspect invitations. These are actual SMTP test messages, not messages to real shelters.

## Explore recovery

Use a second case to try a short handoff or receipt. Keep the original promise and physical count visible. A smaller promise requires the relevant current confirmations; missing food does not automatically become kitchen stock or replacement demand.

For a closed destination, the collector first reports food still carried, location and holding. The coordinator can invite another receiving team. That team accepts and the collector agrees the onward arrival. The new case records carried food without another kitchen pickup. Confirm capacity for the whole load, including any portion still unresolved.

For rejected food, record its actual known outcome before a later return or disposal. Link the later movement to that original report. The same boxes are accounted for once; a kitchen return stays quarantined.

The [architecture](ARCHITECTURE.md) explains these responsibilities. The [validation record](VALIDATION.md) describes the independently checked cases and limits.
