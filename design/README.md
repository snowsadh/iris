# Food rescue interface preview

This is a local, clickable design exercise. One kitchen offers meal boxes to two known receiving partners. The coordinator, kitchen, and receiving contacts have separate views.

The preview uses fictional data and scripted recipient suggestions. It sends no notifications, runs no AI, and has no server or IRIS connection. Food-policy checks and account permissions are not implemented.

## Open it

Open [food-rescue.html](food-rescue.html) in a browser, or serve only this directory:

```bash
python3 -m http.server 8765 --bind 127.0.0.1 --directory design
```

Then open <http://127.0.0.1:8765/food-rescue.html>.

Changes stay in the tab's session storage. Refresh recovers that tab's example; **Start over** clears it. Separate tabs are not a shared coordination service.

## Walk through the complete case

The **Next** control above the product helps you switch participants. Role switching is a preview tool, not a production account feature.

1. **City Kitchen:** Review the 80-box offer, confirm the handling checkbox, and post it. Observe that no pickup is confirmed.
2. **Rescue desk:** Review today's recipient messages. Send 35 boxes to Riverside and 45 to Bridge. Both requests are now held for replies.
3. **Riverside and Bridge:** Confirm quantity, collector, pickup time, and capacity. Each now has a reservation and collection ticket.
4. **City Kitchen:** Open each handoff. Enter the code from that partner's ticket and confirm the physical count. Preview codes: Riverside `314159`; Bridge `271828`.
5. **Each receiving partner:** Confirm actual receipt. Only now does the food count as received.
6. **City Kitchen:** Review the two receipts and the final count.

Use **Advance 10 minutes** to test reply expiry. This changes only the fictional scenario clock.

## Other paths to try

- Accept 20 of Riverside's 35 boxes. The other 15 become available; they do not disappear into a successful allocation.
- Ask for collection help. The coordinator can record Lee's confirmed availability, but the shelter still needs to accept.
- Let an invitation expire. Its old link cannot become a reservation.
- Enter a wrong pickup code. The handoff remains unrecorded.
- Receive 33 of 35 boxes. Record a problem; the coordinator must account for the two remaining boxes separately. The received count stays 33.
- Withdraw unassigned food. Existing commitments remain, and the withdrawn quantity remains visible.

## What is still a design specification

[PRODUCT.md](../doc/PRODUCT.md) includes cases beyond this preview: partner onboarding, verified addresses and phone contacts, actual email delivery, pre-pickup shortages, changed food information, cancellation, network loss, and real-world escalation.

Those behaviors are not implemented by showing a message here. The next implementation must give them persisted records, permissions, actual communication, and native workflow checks. Local button guards do not prove concurrent reservation safety.

## Repeat the browser checks

The check script exercises the complete case, partial quantities, stock limits, expiry, collection help, receipt discrepancies, refresh recovery, and a narrow mobile viewport. It checks this browser prototype only.

Install the browser-test tool outside the project:

```bash
npm install --prefix /tmp/food-preview-check playwright
node /tmp/food-preview-check/node_modules/playwright/cli.js install chromium
FOOD_PREVIEW_PLAYWRIGHT=/tmp/food-preview-check/node_modules/playwright node design/check-flow.cjs
```

If using an existing compatible Chromium binary, supply its path through `FOOD_PREVIEW_BROWSER`. No application package installation or build is required. Screenshots are written under `/tmp/food-rescue-*.png`.
