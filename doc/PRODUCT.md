# Allfedo: the complete product story

Status: proposed behavior, not a working service. Food rescue and a network of known kitchens and shelters with a coordinator are selected. Interviews, local handling rules, and live integration checks remain ahead.

## What this product is responsible for

A kitchen has extra food and limited time. A shelter needs food but must know what is coming and who will collect it. A coordinator brings those commitments together.

The product takes an offer through a clear agreement, named collection, and confirmed receipt. It keeps unfinished work visible when someone does not respond or circumstances change.

The failure this design targets: “We could take some” gets mistaken for “Jamie Taylor will collect 35 boxes at 6 PM.” Food remains at the kitchen because everyone thinks someone else arranged collection. This is a product hypothesis to check with partners, not an interview finding.

It cannot create a driver, guarantee that every offer is collected, or certify food condition. A match is a suggestion until the people involved agree. A notification is not that agreement.

## The people and their situations

| Person | What their day looks like | What they need from the app |
|---|---|---|
| Kitchen contact | Counts surplus while finishing service. May be on a phone and about to leave. | Post once, know whether anyone is coming, see who and when, record the actual handoff. |
| Shelter contact | Knows today's need, storage, receiving hours, and available staff. | Understand the food and commitment before accepting. Accept fewer boxes or ask for collection help. |
| Collector | A named shelter staff member or approved volunteer. May be different from the receiving contact. | One pickup ticket with quantity, address, entrance, time, contacts, and the receiving location. |
| Coordinator | Handles several kitchens and shelters; already makes calls when plans change. | See the cases needing a decision, why a plan fits, and which person must act next. |

People receiving meals do not need accounts. The app does not collect their names or personal circumstances.

## Before the first rescue

The coordinator invites known partner contacts. Each partner confirms its address, named contact, phone, entrance instructions, normal hours, accepted food/handling conditions, and usual collection arrangements. A real deployment needs the network's approved handling and escalation rules for its location.

These are defaults, not today's commitments. A shelter confirms today's quantity, receiving deadline, and collection availability. The screen shows when that information was updated. Unconfirmed details require a question before a reservation can be made.

Transport uses partner staff or approved volunteers under the network's existing arrangements. The collector must be able to carry the actual packaging and follow the network's handling requirements. A contact saying that a van “might be back” is not confirmed transport.

If no partners exist, the coordinator sees **Add a kitchen** and **Add a shelter**, with an explanation of why. The system does not invent nearby organizations or claim that a map result is an approved partner.

## A normal operating day is larger than one rescue

Several kitchens may offer food at once. A shelter's remaining need is shared across all those offers; accepting 30 boxes from one kitchen must reduce what it can still accept elsewhere. The same applies to a collector's time and vehicle capacity.

Offers may contain different lots, packaging, units, deadlines, and holding conditions. Keep those differences visible. A request for 20 trays cannot silently become 20 individual meals. Unknown conversion or handling information needs a specific question or coordinator review.

The coordinator may be handling an undelivered invitation, a quantity shortfall, an unconfirmed collector, and an expected arrival at the same time. The app must show distinct work items with owners and deadlines. A single successful case cannot establish that the network is running smoothly.

Changes preserve previous commitments until explicitly resolved. If food is already with a collector, a missing receipt does not make it available again. Someone must establish its custody and next destination.

The example below teaches the agreement sequence. It is not the full data model or a limit of two shelters. Shared-resource checks and recovery behavior are specified in [TECHNICAL_PLAN.md](TECHNICAL_PLAN.md).

## One rescue, from beginning to end

The following is a fictional case. Times describe partner availability, not a universal food-safety window.

### 1. Alex Morgan counts the kitchen's surplus

At City Kitchen, Alex Morgan has 80 sealed, chilled meal boxes: rice, chickpea curry, and yogurt. The kitchen confirms milk is present and states how the boxes are being held. The food is ready from 5:40 PM and staff can hand it over until 6:20 PM.

She opens **Offer food**. Saved address and entrance details are already present. She confirms:

- Food description and number of boxes.
- Ready-from time and final collection time.
- Known ingredients/allergens and handling information required by the network.
- Who will be present at pickup.

For this case, the sealed boxes go into disposable carry cartons of five. Riverside's 35 boxes therefore need space for seven cartons. Containers requiring return would create another obligation; they are outside the initial case.

She can paste a message to help fill a draft, but extracted values remain visible for her confirmation. Unknown information stays unknown. A photo is optional; it cannot establish ingredients or condition.

The form asks for actual holding information, such as kept chilled, rather than a vague “food safety approved” checkbox. The live service must apply the network's specific rules and display any missing requirement before arranging collection.

She taps **Offer 80 meal boxes**. The result says **Offer posted. No pickup confirmed yet.** Repeating the click or refreshing must recover the same offer.

### 2. The coordinator reviews a concrete plan

The rescue desk shows the offer and today's partner information:

- Riverside Shelter confirmed it can accept 35 boxes and receive until 7 PM. Jamie Taylor wrote, “Our van should be back around six; let me check.” Collection is not yet confirmed.
- Bridge Centre confirmed it can accept 45 boxes and receive until 6:45 PM. Sam Reed can collect around 6:10 PM.

Both organizations have confirmed they can accept the declared food under their handling requirements. This does not establish suitability for every individual.

The agent proposes those two requests, with Riverside's collection question attached. Each row explains its basis: current quantity, food requirements, receiving hours, and collection arrangement. A known travel estimate and loading time must fit the receiving window, with the contact confirming they can make the trip. The coordinator can change the split or ask for missing information.

The coordinator can record a phone/message update with its sender and time. The agent can interpret informal replies, but an uncertain “maybe” must remain uncertain. Extracted changes are proposals until confirmed by the responsible contact.

The coordinator taps **Send 2 offers**. The system temporarily holds 35 and 45 boxes while recipients reply. In this example, holds last ten minutes and the invitation shows an exact expiry. The live duration must be chosen with the network and cannot extend beyond collection availability.

The agent helps interpret messages, identify missing information, and choose an outreach plan. Code checks quantities and deadlines. The coordinator owns sending the initial plan; the agent cannot claim anyone accepted it.

### 3. Each shelter makes an actual commitment

Jamie Taylor sees **35 meal boxes offered by City Kitchen**, the food details, pickup window, receiving address, and reply deadline.

She chooses **Accept 35 boxes**, selects an approved collector, and confirms a pickup time and transport capacity. If someone else will collect, that person receives a restricted pickup ticket. If she needs fewer, she changes the quantity before accepting. Unneeded boxes become available again.

**Need help collecting** alerts the coordinator and keeps the invitation explicitly pending. It does not create a confirmed pickup. The coordinator must obtain a named approved collector and a valid time, or explain that collection could not be arranged.

The server confirms the reservation against current stock and the current offer. Both parties then see **Jamie Taylor will collect 35 boxes at 6 PM**. Sam Reed separately confirms 45 at 6:10 PM.

A delivered invitation, an opened page, and a confirmed reservation remain different facts. An expired link cannot confirm an old quantity.

### How requests reach people

The first design uses an in-app inbox and an email notification linking to the same request. Contacts sign in with their invited account. A collector sees only their assigned ticket. Email delivery failure appears at the rescue desk; the coordinator can call using the saved contact details. A successful email send never confirms acceptance.

The demo may use a local email inbox instead of real recipients. It must identify that clearly. Live email, SMS, or messaging-service integrations must be checked separately; no messages have been sent during design work.

### 4. Someone physically collects the boxes

The pickup ticket contains the kitchen entrance, both contacts, quantity, food details, pickup time, destination, and a collection code. Only authorized participants see this information.

The collector travels to the kitchen. Alex Morgan checks the ticket/code and counts the boxes being handed over. She records **Handed over 35 boxes**. The code associates the handoff with the correct reservation; it is not proof of food condition.

If the count differs, the app requires the people involved to agree on the changed amount and alerts the coordinator. A shortfall cannot silently reduce another reservation.

After collection, the food is recorded as with the collector. It cannot be offered again because the receiving shelter has not yet acknowledged it.

### 5. Receiving staff confirms what arrived

The collector goes to the agreed receiving location. The named receiving contact checks the delivery and taps **Received all 35 boxes**, or reports the actual accepted quantity and problem.

Only then does that collection show **Received**. The kitchen sees the outcome without another phone call. The coordinator sees what remains unfinished. After Bridge confirms its 45, the original offer shows **80 boxes received across 2 shelters**.

The product does not convert this into “80 people fed.” Receipt does not establish consumption or nutritional impact.

## The promises behind the labels

| Label | What is known | Who acts next |
|---|---|---|
| Available | Kitchen offered these boxes; nobody has accepted them. | Coordinator prepares requests. |
| Waiting for reply | An exact quantity is held until an exact time. | Shelter accepts, changes quantity, or declines. |
| Pickup confirmed | Recipient, quantity, collector, and pickup time are agreed. | Collector and kitchen complete the handoff. |
| Collected | Kitchen recorded a physical handoff. | Receiving contact confirms actual receipt. |
| Received | Receiving contact confirmed the accepted quantity. | No further action for those boxes. |
| Needs attention | A specific agreement or handoff has a problem. | Named coordinator handles the stated next action. |
| Not collected | The opportunity ended without a recorded handoff. | Kitchen follows its own handling procedure. |

Counts remain separate. “35 received” cannot also appear as “35 available.” A receipt shortfall stays unresolved until its outcome is accounted for. Closing an offer records its uncollected remainder; it does not imply that all food was rescued or wasted.

## When real life interrupts

| What happens | What the person sees and can do | What changes |
|---|---|---|
| A shelter does not reply | Coordinator sees who has not replied and the hold expiry. | Unaccepted quantity is released at expiry; no acceptance is invented. |
| A shelter accepts fewer boxes | Shelter sees the exact amount it is accepting. | Only that amount is reserved; the difference is released. |
| Two requests compete for remaining stock | The later request gets the current quantity and a chance to revise. | A server check prevents two confirmations for the same boxes. |
| Nobody can collect | Shelter sees **Collection help requested**; coordinator sees a task with a deadline. | No confirmed pickup until someone actually agrees. No invented driver or ETA. |
| Kitchen has fewer boxes | Kitchen reports the new physical count; coordinator sees the shortfall. | Stop new offers that depend on missing stock; affected commitments require an explicit change. |
| Food details change | Affected partners see exactly what changed. | Pause affected collection plans and require review/reconfirmation under network rules. |
| A collector is late or cancels | Kitchen/collector reports the problem; the coordinator contacts both parties. | Reassign only after the replacement agrees. Any extension requires the kitchen's new confirmation and applicable handling checks. |
| Nobody is at the receiving location | Collector can reach the coordinator from the ticket. | Keep custody with the collector. Redirect only after an eligible receiving partner accepts. |
| Receipt is 33 rather than 35 | Receiving staff records 33 and the problem. Coordinator gets a two-box discrepancy. | Count 33 as received. Keep the remaining outcome explicit; never return it automatically to available stock. |
| A page is offline | Saved instructions remain distinguishable from current confirmation. An unsent request says **Not sent**. | Drafts may wait for reconnection. Confirmations require a server response. Existing network phone procedures are the fallback. |
| A reply was lost | The person refreshes or checks the request. | Recover the saved outcome before retrying. Never make a second reservation merely because a page timed out. |
| The model is unavailable | Coordinator sees current partner facts and can prepare the plan manually. | Normal checks still apply. Record who made the decision; do not invent an AI result. |
| No suitable partner exists | Kitchen sees **No pickup arranged**; coordinator sees the exact obstacle. | Stop at the agreed deadline. Do not leave “matching” running indefinitely. |

No system can resolve every field situation automatically. Each unresolved case must retain an owner, a next action, and a deadline. A manual phone confirmation records who supplied it and who entered it; it must not masquerade as a recipient's digital confirmation.

## What belongs in the first release

- One local network, known partners, and individually packaged meal boxes.
- Kitchen offers; today's shelter needs; coordinator review; invitations and quantity holds.
- Named collector and pickup agreement; handoff and receiving confirmation.
- Clear quantity changes, expiry, duplicate requests, cancellation, and discrepancy handling.
- Real contact instructions, visible ownership, and a readable case history.

Bulk food conversion, open public signup, a driver marketplace, route optimization, automatic safety certification, and guaranteed offline reservations are later questions. They must not be implied by the first interface.

## What still needs discovery

We have no partner interviews or field trial. Confirm: operating location and approved handling procedure; how partners currently communicate; who can approve changes; realistic response/collection times; who has transport; and whether packaging/collection support needs a different first scope.

The example names, quantities, times, and roles are design fixtures. They are not evidence of partner participation or measured savings.

## Sources and what was reused

- [Feeding Charlotte recipient process](https://feedingcharlotte.org/become-a-recipient/) describes partner capacity profiles, named contacts, assigned receiving staff, and delivery confirmation. These informed the responsibility chain.
- [Food Rescue Hero donor intake](https://admin.foodrescuehero.org/donations/intake/hunger_network) collects availability, packaging, quantity, vehicle fit, and handling attestations. These informed the offer questions.
- [Food Rescue Hero collection tracking](https://foodrescuehero.org/introducing-multi-stop-rescues/) describes tracking pickups and dropoffs and the operational cost of incomplete records. This informed separate handoff and receipt steps.

These are examples from US organizations. Their legal terms and handling policies are not adopted as local rules. The proposed agreement flow and interface are this project's design; no source application code was reused.
