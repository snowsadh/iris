# Food rescue: screen and interaction plan

Read [PRODUCT.md](PRODUCT.md) for the full case. This file specifies what a person sees and what their action means. All screens remain proposed until implemented and checked.

## Rules for every screen

- Lead with the person's task, food, quantity, and relevant deadline.
- Show the next responsible person and one clear primary action.
- Use plain actions: **Offer food**, **Send offers**, **Accept 35 boxes**, **Confirm handoff**, **Confirm receipt**.
- Explain a change where it matters. Do not hide it in a notification feed.
- Show committed results only after the server confirms them. A spinning button is not acceptance.
- Keep entered information after a correctable failure. A repeated click must recover the same operation.
- Use visible labels and readable status text. Color alone never conveys an outcome.
- Keep technical traces and model details in an optional inspection view, outside everyday tasks.

## Screen 1: the kitchen's offer

Saved partner details appear as a small pickup summary. Fresh food details are confirmed for every offer.

```text
City Kitchen                         Asha
Offer food

What is available?
[Rice, chickpea curry and yogurt        ]
Number of meal boxes [80]
Ready from [5:40 PM]   Collect by [6:20 PM]
Ingredients / allergens [Contains milk ]
Handling details [network-required data]

Pickup: rear entrance · Asha on site
[Change pickup details]

[Offer 80 meal boxes]
```

Required information stays on one page. Optional message-to-draft entry is secondary. No AI chat is needed to fill a normal offer.

After posting, replace the form with the offer ticket: **80 available · no pickup confirmed**. Later show each named collector, time, and quantity. Do not show “Donation complete” after posting.

## Screen 2: the coordinator's rescue desk

The opening screen answers **What needs me now?** Cases needing a decision appear first. Each row gives the specific obstacle and action, such as **Bridge needs a collector — reply by 6:05 PM — Arrange collection**.

Scheduled pickups and completed receipts remain available without dominating the page. No global map, carbon estimate, arbitrary score, or stream of “AI activity.”

Opening an offer puts stable food facts beside the proposed recipient requests:

```text
City Kitchen · 80 meal boxes · collect by 6:20 PM
Rice, chickpea curry and yogurt · contains milk
Kitchen contact: Asha · rear entrance

Recipient             Boxes   Why this can work
Riverside Shelter     [35]    Need confirmed; ask Maya to confirm pickup
Bridge Centre         [45]    Need confirmed today; Omar can collect

80 held if sent · replies due 6:05 PM
[Send 2 offers]
```

The proposed plan is editable. Current need and travel/collection facts must have an identifiable source. An uncertain arrangement says **Needs confirmation**, not “98% match.” Recent receipts can help the coordinator make distribution decisions; no unexplained fairness score is claimed.

Riverside's source message says its van may be back around six. Show that exact uncertainty next to the proposed request. The person should understand why a collection confirmation is being requested.

After sending, the main content becomes the two actual requests and their reply states. It does not keep presenting the same suggestion as unfinished AI work.

## Screen 3: the shelter's invitation

```text
35 meal boxes offered to Riverside Shelter
From City Kitchen
Rice, chickpea curry and yogurt · contains milk
Ready 5:40 PM · collect by 6:20 PM
Reply by 6:05 PM

How many can you take? [35]
Who will collect? [Maya]
Pickup time [6:00 PM]

[Accept 35 boxes]
[Need help collecting]     [Decline]
```

Acceptance makes a commitment. The final response repeats the agreed quantity and time. An expired or changed offer explains what happened and shows current choices.

Collection help creates a coordinator task. Show whether a hold remains and when it ends. It must not say that a driver is on the way.

## Screen 4: the pickup ticket

This is a compact, mobile page for the specific collection. It contains both locations, entrance instructions, contacts, quantity, food details, pickup time, and authorized collection code.

Kitchen staff record the real handoff. **Confirm handoff of 35 boxes** opens a short confirmation with the collector's name and actual count. Changed counts require agreement; the app cannot silently complete the original amount.

Directions open the device's map tool. Contact actions use verified partner details. Viewing the ticket never changes a collection's status.

## Screen 5: receiving confirmation

After collection, the receiving contact sees **35 boxes collected by Maya — confirm what arrived**.

- **Received all 35 boxes** records that explicit confirmation.
- **Report a different quantity or problem** reveals actual accepted count and the issue.

A short receipt follows. For a discrepancy: **33 boxes received. Coordinator follow-up needed for 2.** A reassuring success toast must not cover that unresolved difference.

## Failures need instructions

| Avoid | Use |
|---|---|
| Processing donation | Waiting for Riverside to accept 35 boxes. Reply due 6:05 PM. |
| Allocation optimized | Proposed: 35 boxes to Riverside, 45 to Bridge. Review before sending. |
| Something went wrong | Your reply was not sent. Check the connection and try again. |
| Offer unavailable | This offer expired at 6:05 PM. No boxes were reserved for you. |
| Rescue completed | Riverside confirmed receipt of 35 boxes. |
| Failed delivery | Receiving staff could not be reached. Coordinator Lee needs to confirm another receiving location. |

Use the specific error actually observed. If the server's outcome is unknown, say **Checking whether your acceptance was saved** and recover it before asking for another submission.

## Visual direction

The interface should feel like a clear pickup ticket used by busy staff. Its signature is the same food, quantity, time, and responsible-person block carried from offer to invitation to receipt. The wording changes to match what is actually known.

- Ink `#203735`, paper `#F7FAF9`, action green `#27664D`, attention amber `#8C5200`, problem red `#A82E36`, divider `#D7E2DB`.
- Large plain quantity and time; compact headings. Prefer Barlow Semi Condensed for headings and Atkinson Hyperlegible for body text, with local system fallbacks. A preview must work without downloading fonts.
- One column on phones. The coordinator's detail screen may use two columns on wider screens.
- Large touch controls, visible keyboard focus, persistent form labels, readable contrast, and no motion needed to understand state.

Design critique: a donation landing page with impact counters would consume space without arranging food. The pickup ticket and action queue are more appropriate. Green is reserved for actions and confirmed states; amber/red mean an actual exception, not decorative urgency.

## Review before calling the design ready

Give someone only the screen. Can they identify the food, available quantity, relevant deadline, responsible person, and consequence of the primary button?

Walk through posting, split requests, accepting fewer, expiry, pickup, receipt, and one discrepancy. Every visible state must explain the next step. A complete receipt must be traceable to the original offer without treating a notification or suggestion as physical evidence.

Any clickable preview uses fictional local data. It does not demonstrate live messaging, real food movement, authentication, or an AI Hub run. Production accounts will be scoped to the person's organization; switching roles belongs only in the preview controls.
