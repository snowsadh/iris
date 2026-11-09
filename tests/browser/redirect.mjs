/** Real onward delivery using five native accounts. No provider call or invented kitchen pickup. */
import assert from "node:assert/strict";

export async function onwardJourney(ui) {
  const { kitchen, recipient, coordinator, collector, recipient2 } = ui.pages;
  const { get, open, shot, clock } = ui;
  const waitSaved = (page, text) =>
    page.getByRole("status").filter({ hasText: text }).waitFor();
  ui.setStep("Confirming the second receiving team’s actual window");
  await ui.saveSite(
    recipient2,
    "Riverside Center",
    "83 River Road",
    "Main reception door",
  );
  const targetExisting = (await get(recipient2, "needs")).records.find(
    (need) =>
      Number(need.held_quantity) === 0 && Number(need.committed_quantity) === 0,
  );
  const targetClock = await get(recipient2, "session");
  await open(
    recipient2,
    targetExisting ? `/needs/${targetExisting.id}/edit` : "/needs/new",
  );
  await recipient2.locator("#need-quantity").fill("30");
  await recipient2
    .locator("#need-receiving-from")
    .fill(clock(targetClock.now, -2));
  await recipient2.locator("#need-receiving").fill(clock(targetClock.now, 120));
  await recipient2.locator("#need-confirmed").fill(clock(targetClock.now, 110));
  for (const box of await recipient2
    .locator('input[name="excluded_allergens"]')
    .all())
    await box.uncheck();
  for (const box of await recipient2
    .locator('input[name="accepted_holding"]')
    .all())
    await box.uncheck();
  await recipient2
    .locator('input[name="excluded_allergens"][value="peanut"]')
    .check();
  await recipient2
    .locator('input[name="accepted_holding"][value="chilled"]')
    .check();
  await recipient2
    .getByLabel(
      "I confirm this total and the receiving requirements for our team.",
    )
    .check();
  await recipient2
    .getByRole("button", {
      name: targetExisting ? "Update receiving need" : "Confirm receiving need",
      exact: true,
    })
    .click();
  await recipient2.waitForURL(/#\/needs\/\d+$/);
  const targetId = recipient2.url().match(/#\/needs\/(\d+)$/)[1];
  const oldNeed = (await get(recipient, "needs")).records.find(
    (need) => need.state === "open" && Number(need.remaining_quantity) >= 20,
  );
  assert.ok(
    oldNeed,
    "The first receiving team must have actual confirmed remaining need.",
  );

  ui.setStep(
    "Collecting food once before the first destination becomes unavailable",
  );
  await ui.enterFood(
    kitchen,
    `Prepared vegetable rice · onward check ${ui.token}`,
  );
  await kitchen.locator("#food-quantity").fill("20");
  await kitchen
    .locator("#food-packaging")
    .fill("4 carry cartons, each containing 5 sealed meal boxes.");
  await kitchen
    .getByRole("button", { name: "Send food details for review", exact: true })
    .click();
  await kitchen.waitForURL(/#\/offers\/\d+$/);
  const offerId = kitchen.url().match(/#\/offers\/(\d+)$/)[1];
  await open(coordinator, `/offers/${offerId}/plan`);
  await coordinator.locator(`#plan-${oldNeed.id}`).fill("20");
  await coordinator
    .locator("#plan-reason")
    .fill(
      "The first receiving team confirmed the current chilled receiving window and peanut exclusion. Invite 20 meal boxes.",
    );
  await coordinator
    .getByRole("button", { name: "Review this draft", exact: true })
    .click();
  await coordinator
    .getByLabel(
      "I have reviewed the quantities, food requirements and receiving windows.",
    )
    .check();
  await coordinator
    .getByRole("button", { name: "Send these invitations", exact: true })
    .click();
  await coordinator.waitForURL(/#\/allocations\?/);
  const parentId = (await get(coordinator, `allocations?offer_id=${offerId}`))
    .records[0].id;
  await open(recipient, `/allocations/${parentId}`);
  await recipient.locator("#accept-quantity").fill("20");
  await recipient
    .getByLabel(
      "I confirm our team can receive this food under the recorded requirements.",
    )
    .check();
  await recipient
    .getByRole("button", { name: "Reserve these meal boxes", exact: true })
    .click();
  await recipient.locator("#collector-choice").selectOption(ui.collectorId);
  await recipient
    .getByRole("button", { name: "Assign collector", exact: true })
    .click();
  await waitSaved(recipient, "Collector assigned.");
  await collector.setViewportSize({ width: 390, height: 844 });
  await open(collector, `/allocations/${parentId}`);
  const tripClock = await get(collector, "session");
  await collector.locator("#trip-pickup").fill(clock(tripClock.now, 2));
  await collector.locator("#trip-arrival").fill(clock(tripClock.now, 30));
  await collector.locator("#trip-capacity").fill("20");
  await collector.locator('input[name="handling"]').check();
  await collector
    .getByRole("button", { name: "Confirm my trip", exact: true })
    .click();
  await waitSaved(collector, "Your trip is agreed.");
  await open(kitchen, `/allocations/${parentId}`);
  await kitchen.locator("#handoff-count").fill("18");
  await kitchen
    .locator("#handoff-note")
    .fill(
      "18 boxes handed to the collector. Two boxes remain in the kitchen cold room.",
    );
  await kitchen
    .getByLabel(
      "The named collector is here and this quantity has physically changed hands.",
    )
    .check();
  await kitchen
    .getByRole("button", { name: "Record actual handoff", exact: true })
    .click();
  await waitSaved(kitchen, "The kitchen handoff is recorded.");
  let parent = (await get(collector, `allocations/${parentId}`)).record;
  assert.equal(parent.collected_quantity, "18");
  assert.equal(parent.recovery.kitchen_handoff_quantity, "18");
  assert.equal(
    parent.recovery.custody_history.find(
      (report) => report.active && report.kind === "handoff",
    ).agreement_issue,
    "",
  );
  await open(kitchen, `/offers/${offerId}`);
  await kitchen
    .getByText("Report a changed physical count", { exact: true })
    .click();
  await kitchen.locator("#stock-quantity").fill("2");
  await kitchen
    .locator("#stock-note")
    .fill(
      "Counted the two unhanded boxes still in the kitchen cold room. No carried food has returned.",
    );
  await kitchen
    .getByRole("button", { name: "Report the changed count", exact: true })
    .click();
  await waitSaved(kitchen, "Changed count recorded.");

  ui.setStep(
    "Collector reports the blocked destination with an actual current count and location",
  );
  await open(collector, `/allocations/${parentId}`);
  await collector
    .getByText("Receiving point unavailable? Report the food still with you", {
      exact: true,
    })
    .click();
  await collector.locator("#destination-custody").fill("18");
  const privateLocation =
    "Outside the locked Westside reception gate, 28 Westside Avenue";
  await collector.locator("#destination-location").fill(privateLocation);
  await collector.locator("#destination-handling").selectOption("yes");
  await collector
    .locator("#destination-note")
    .fill(
      "The agreed receiving door is locked and the contact is not answering. All 18 boxes remain chilled with me.",
    );
  await collector
    .getByLabel(
      "This is my current count and location. I have not handed these boxes to the receiving team.",
    )
    .check();
  await collector
    .getByRole("button", {
      name: "Save current food and location report",
      exact: true,
    })
    .click();
  await waitSaved(
    collector,
    "Current food, location and handling report saved.",
  );
  parent = (await get(collector, `allocations/${parentId}`)).record;
  assert.equal(parent.state, "destination_issue");
  assert.equal(parent.recovery.redirect.available_quantity, "18");
  assert.equal(
    parent.recovery.redirect.issue.current_location,
    privateLocation,
  );
  await shot(collector, "onward-driver-blocked-mobile");
  // The first receiving contact takes no further action: being unreachable cannot block a safe onward invitation.
  await open(coordinator, `/allocations/${parentId}`);
  await coordinator
    .getByText("Release a remainder that never left the kitchen", {
      exact: true,
    })
    .click();
  await coordinator.locator("#unavailable-release").fill("2");
  await coordinator
    .locator("#unavailable-reason")
    .fill(
      "The original receiving point is unavailable. The kitchen’s actual count confirms the two unhanded boxes remain there.",
    );
  await coordinator
    .getByLabel(
      "I reviewed the kitchen’s actual count. This release does not return carried food to the kitchen.",
    )
    .check();
  await coordinator
    .getByRole("button", { name: "Release uncollected remainder", exact: true })
    .click();
  await waitSaved(coordinator, "Uncollected promise released");
  parent = (await get(coordinator, `allocations/${parentId}`)).record;
  assert.equal(parent.quantity, "18");
  assert.equal(parent.recovery.unhanded_quantity, "0");
  assert.equal(parent.recovery.original_promise_quantity, "20");

  async function invite(quantity, screenshot = false) {
    await open(coordinator, `/allocations/${parentId}`);
    await coordinator
      .getByRole("link", { name: "Find another receiving point", exact: true })
      .click();
    await coordinator
      .locator(`a[href="#/allocations/${parentId}/redirect?need=${targetId}"]`)
      .click();
    await coordinator.locator("#redirect-quantity").fill(String(quantity));
    await coordinator
      .locator("#redirect-reason")
      .fill(
        "Riverside confirmed chilled handling, peanut exclusion and a current receiving window. The food is already with the collector.",
      );
    if (screenshot) await shot(coordinator, "onward-coordinator-review");
    await coordinator
      .getByLabel(
        "I reviewed this team’s food requirements and receiving window. The collector must still confirm the onward trip.",
      )
      .check();
    await coordinator
      .getByRole("button", { name: "Send onward food invitation", exact: true })
      .click();
    await coordinator.waitForURL(/#\/allocations\/\d+$/);
    const childId = coordinator.url().match(/#\/allocations\/(\d+)$/)[1];
    assert.notEqual(childId, parentId);
    return childId;
  }
  async function acceptAndDrive(
    childId,
    quantity,
    capacity,
    screenshot = false,
  ) {
    await open(kitchen, `/allocations/${childId}`);
    assert.equal(
      await kitchen
        .getByRole("button", { name: "Withdraw invitation", exact: true })
        .count(),
      0,
      "The origin kitchen cannot withdraw a held onward invitation; the coordinator owns it.",
    );
    await recipient2.setViewportSize({ width: 390, height: 844 });
    await open(recipient2, `/allocations/${childId}`);
    let child = (await get(recipient2, `allocations/${childId}`)).record;
    assert.equal(child.recovery.redirect.parent_readable, false);
    assert.equal(child.recovery.current_context.details.in_transit, true);
    assert.equal(
      child.recovery.current_context.details.custody.location,
      undefined,
    );
    assert.equal(JSON.stringify(child).includes(privateLocation), false);
    assert.equal(JSON.stringify(child).includes("28 Westside Avenue"), false);
    assert.equal(
      await recipient2
        .getByRole("link", {
          name: "Open the original collection",
          exact: true,
        })
        .count(),
      0,
    );
    assert.equal(
      await recipient2.evaluate(
        async (id) => (await fetch(`/allfedo/api/allocations/${id}`)).status,
        parentId,
      ),
      404,
    );
    assert.equal(
      await recipient.evaluate(
        async (id) => (await fetch(`/allfedo/api/allocations/${id}`)).status,
        childId,
      ),
      404,
    );
    await recipient2.locator("#accept-quantity").fill(String(quantity));
    await recipient2
      .getByLabel(
        "I confirm our team can receive this food under the recorded requirements.",
      )
      .check();
    if (screenshot) await shot(recipient2, "onward-target-invitation-mobile");
    await recipient2
      .getByRole("button", { name: "Reserve these meal boxes", exact: true })
      .click();
    await waitSaved(
      recipient2,
      "Food reserved from the existing carried load.",
    );
    child = (await get(recipient2, `allocations/${childId}`)).record;
    assert.equal(child.collected_quantity, String(quantity));
    assert.equal(child.recovery.kitchen_handoff_quantity, "0");
    assert.equal(
      child.recovery.redirect.transferred_in_quantity,
      String(quantity),
    );
    assert.equal(await recipient2.locator("#collector-choice").count(), 0);
    await open(collector, `/allocations/${childId}`);
    assert.equal(
      await collector
        .locator(".collection-actions .action-form")
        .first()
        .getByRole("heading", {
          name: "Agree the onward destination and arrival",
          exact: true,
        })
        .count(),
      1,
      "The immediate onward agreement must precede optional problem reports.",
    );
    assert.equal(await collector.locator("#trip-pickup").count(), 0);
    assert.equal(
      await collector.locator("#redirect-capacity").getAttribute("min"),
      String(capacity),
    );
    const now = await get(collector, "session");
    await collector.locator("#redirect-arrival").fill(clock(now.now, 25));
    await collector.locator("#redirect-capacity").fill(String(capacity));
    await collector
      .getByLabel(
        "I checked the new destination and can maintain the recorded food holding conditions until arrival.",
      )
      .check();
    if (screenshot) await shot(collector, "onward-driver-agreement-mobile");
    await collector
      .getByRole("button", {
        name: "Confirm onward destination and arrival",
        exact: true,
      })
      .click();
    await waitSaved(collector, "Onward destination and arrival agreed.");
    child = (await get(collector, `allocations/${childId}`)).record;
    assert.equal(Boolean(child.transport_confirmed), true);
    assert.equal(child.recovery.agreed_trip.details.in_transit, true);
    await open(kitchen, `/allocations/${childId}`);
    assert.equal(
      await kitchen.locator("#handoff-count").count(),
      0,
      "A carried child cannot ask for another kitchen handoff.",
    );
    await open(recipient2, `/allocations/${childId}`);
    await recipient2.locator("#receipt-count").fill(String(quantity));
    await recipient2
      .locator("#receipt-note")
      .fill(
        `${quantity} boxes counted and accepted at Riverside. This is the onward arrival of food already collected.`,
      );
    await recipient2
      .getByLabel("I have counted the food at our receiving point.")
      .check();
    await recipient2
      .getByRole("button", { name: "Record receiving count", exact: true })
      .click();
    await waitSaved(recipient2, "Receiving count recorded.");
    child = (await get(recipient2, `allocations/${childId}`)).record;
    assert.equal(child.state, "received");
    assert.equal(child.received_quantity, String(quantity));
    assert.equal(
      child.recovery.custody_history.find(
        (report) => report.active && report.kind === "receipt",
      ).agreement_issue,
      "",
    );
    if (screenshot) await shot(recipient2, "onward-received-mobile");
  }

  ui.setStep(
    "An onward invitation is partially accepted and the collector agrees the whole carried load",
  );
  const firstChild = await invite(18, true);
  parent = (await get(coordinator, `allocations/${parentId}`)).record;
  assert.equal(parent.recovery.redirect.pending_quantity, "18");
  assert.equal(
    parent.recovery.redirect.available_quantity,
    "0",
    "A pending invitation cannot leave the same food available twice.",
  );
  await acceptAndDrive(firstChild, 15, 18, true);
  parent = (await get(collector, `allocations/${parentId}`)).record;
  assert.equal(parent.recovery.redirect.transferred_out_quantity, "15");
  assert.equal(parent.recovery.physical_unknown_quantity, "3");
  assert.equal(parent.collected_quantity, "18");

  ui.setStep(
    "The remaining carried food gets its own confirmed onward invitation",
  );
  await open(collector, `/allocations/${parentId}`);
  await collector
    .getByText("Update your current food and location report", { exact: true })
    .click();
  await collector.locator("#destination-custody").fill("3");
  await collector
    .locator("#destination-location")
    .fill("Outside Riverside Center’s main reception door, 83 River Road");
  await collector.locator("#destination-handling").selectOption("yes");
  await collector
    .locator("#destination-note")
    .fill(
      "15 accepted at Riverside. The remaining 3 from the original collection are still chilled with me at Riverside’s entrance.",
    );
  await collector
    .getByLabel(
      "This is my current count and location. I have not handed these boxes to the receiving team.",
    )
    .check();
  await collector
    .getByRole("button", {
      name: "Save current food and location report",
      exact: true,
    })
    .click();
  await waitSaved(
    collector,
    "Current food, location and handling report saved.",
  );
  const secondChild = await invite(3);
  await acceptAndDrive(secondChild, 3, 3);
  parent = (await get(coordinator, `allocations/${parentId}`)).record;
  assert.equal(parent.state, "redirected");
  assert.equal(
    parent.received_quantity,
    "0",
    "Onward receipt cannot become a receipt by the unavailable old partner.",
  );
  assert.equal(parent.recovery.kitchen_handoff_quantity, "18");
  assert.equal(parent.recovery.redirect.transferred_out_quantity, "18");
  assert.equal(parent.recovery.physical_unknown_quantity, "0");
  assert.equal(parent.recovery.original_promise_quantity, "20");
  const food = (await get(kitchen, `offers/${offerId}`)).record;
  assert.equal(
    food.collected_quantity,
    "18",
    "Linked custody does not create a second kitchen collection.",
  );
  assert.equal(
    food.stock_projection.usable_on_hand_quantity,
    "2",
    "The two real kitchen boxes stay separate from the carried food.",
  );
  const oldAfter = (await get(recipient, `needs/${oldNeed.id}`)).record;
  assert.equal(oldAfter.state, "availability_review");
  assert.equal(
    oldAfter.remaining_quantity,
    "0",
    "Unreachable partner capacity needs its own fresh confirmation.",
  );
  const targetAfter = (await get(recipient2, `needs/${targetId}`)).record;
  assert.equal(targetAfter.committed_quantity, "18");
  assert.equal(targetAfter.remaining_quantity, "12");
  await open(coordinator, `/allocations/${parentId}`);
  assert.equal(
    await coordinator
      .getByText("Accepted on this original case", { exact: true })
      .count(),
    1,
    "The original receiver’s0 must not look like a total across linked receiving cases.",
  );
  assert.equal(
    await coordinator
      .getByRole("link", {
        name: "Onward collection · 15 meal boxes accepted",
        exact: true,
      })
      .count(),
    1,
  );
  assert.equal(
    await coordinator
      .getByRole("link", {
        name: "Onward collection · 3 meal boxes accepted",
        exact: true,
      })
      .count(),
    1,
  );
  await shot(coordinator, "onward-original-case");
  for (const page of [collector, recipient2])
    assert.equal(
      await page.evaluate(
        () => document.documentElement.scrollWidth > innerWidth,
      ),
      false,
    );
  ui.results.push(
    "Actual onward delivery: 18 collected once, original point unavailable, kitchen-backed 2-box release, held18 invitation/partial15 acceptance/full18 carrying agreement/15 received, then separate3 accepted and received. Old partner stays unconfirmed; parent/child privacy holds; no duplicate pickup or kitchen restock.",
  );
}
