# Food rescue

Help known kitchens and shelters turn surplus food into agreed pickups and confirmed receipts, with a coordinator handling unresolved work.

**Current stage: product design.** No live food-rescue service or IRIS workflow has been implemented. Example partners and quantities are fictional.

- [Clickable interface preview](design/food-rescue.html) and [walkthrough](design/README.md): follow one case across the kitchen, coordinator, and receiving partners.
- [Complete product story](doc/PRODUCT.md): people, commitments, physical handoffs, and failure handling.
- [Screen plan](doc/INTERFACE.md): actions, wording, and visual direction.
- [Submission checklist](doc/SUBMISSION.md): required work and optional bonuses.
- [Platform research](doc/INFO.md) and [project journey](doc/JOURNEY.md).

Product design starts with real responsibilities: an offer is not a reservation, collection is not receipt, and unresolved food must retain an owner and a next action.

To open the preview locally:

```bash
python3 -m http.server 8765 --bind 127.0.0.1 --directory design
```

Visit <http://127.0.0.1:8765/food-rescue.html>. It uses local sample data, not a backend service.
