/** Later movements of already-rejected food stay linked and never become additional accepted meals. */
import assert from "node:assert/strict";

export async function rejectedFoodJourney(ui) {
  const { kitchen, coordinator, collector, recipient2 } = ui.pages;
  const { open, get, shot, clock } = ui;
  const saved = (page, text) =>
    page.getByRole("status").filter({ hasText: text }).waitFor();
  ui.setStep("Creating one real collection for rejected-food follow-up");
  const need = (await get(recipient2, "needs")).records.find(
    (row) => row.state === "open" && Number(row.remaining_quantity) >= 4,
  );
  assert.ok(need, "Riverside needs four actually available receiving slots.");
  await ui.enterFood(
    kitchen,
    "Chilled vegetable meals",
  );
  await kitchen.locator("#food-quantity").fill("4");
  await kitchen
    .locator("#food-packaging")
    .fill("One carry carton containing four sealed meal boxes.");
  await kitchen
    .getByRole("button", { name: "Send food details for review", exact: true })
    .click();
  await kitchen.waitForURL(/#\/offers\/\d+$/);
  const offerId = kitchen.url().match(/#\/offers\/(\d+)$/)[1];
  await open(coordinator, `/offers/${offerId}/plan`);
  await coordinator.locator(`#plan-${need.id}`).fill("4");
  await coordinator
    .locator("#plan-reason")
    .fill(
      "Riverside confirmed a current need and handling for four chilled meal boxes; excluded peanut was checked absent.",
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
  const allocationId = (
    await get(coordinator, `allocations?offer_id=${offerId}`)
  ).records[0].id;
  await open(recipient2, `/allocations/${allocationId}`);
  await recipient2.locator("#accept-quantity").fill("4");
  await recipient2
    .getByLabel(
      "I confirm our team can receive this food under the recorded requirements.",
    )
    .check();
  await recipient2
    .getByRole("button", { name: "Reserve these meal boxes", exact: true })
    .click();
  await recipient2.locator("#collector-choice").selectOption(ui.collectorId);
  await recipient2
    .getByRole("button", { name: "Assign collector", exact: true })
    .click();
  await saved(recipient2, "Collector assigned.");
  await open(collector, `/allocations/${allocationId}`);
  const tripClock = await get(collector, "session");
  await collector.locator("#trip-pickup").fill(clock(tripClock.now, 2));
  await collector.locator("#trip-arrival").fill(clock(tripClock.now, 25));
  await collector.locator("#trip-capacity").fill("4");
  await collector.locator('input[name="handling"]').check();
  await collector
    .getByRole("button", { name: "Confirm my trip", exact: true })
    .click();
  await saved(collector, "Your trip is agreed.");
  await open(kitchen, `/allocations/${allocationId}`);
  await kitchen.locator("#handoff-count").fill("4");
  await kitchen
    .getByLabel(
      "The named collector is here and this quantity has physically changed hands.",
    )
    .check();
  await kitchen
    .getByRole("button", { name: "Record actual handoff", exact: true })
    .click();
  await saved(kitchen, "The kitchen handoff is recorded.");
  await open(recipient2, `/allocations/${allocationId}`);
  await recipient2.locator("#receipt-count").fill("2");
  await recipient2
    .locator("#receipt-note")
    .fill(
      "Two boxes accepted. Two damaged boxes were rejected and remain held separately at this receiving site.",
    );
  await recipient2
    .getByLabel("I have counted the food at our receiving point.")
    .check();
  await recipient2
    .getByRole("button", { name: "Record receiving count", exact: true })
    .click();
  await saved(recipient2, "Receiving count recorded.");
  await recipient2
    .getByText("Record a known outcome for food not accepted", { exact: true })
    .click();
  await recipient2.locator("#outcome-kind").selectOption("rejected_at_site");
  await recipient2.locator("#outcome-quantity").fill("2");
  await recipient2
    .locator("#outcome-note")
    .fill(
      "Two damaged boxes are kept separately at Riverside. They are not accepted, returned or disposed of yet.",
    );
  await recipient2
    .getByLabel(
      "I can confirm this physical outcome. This is not a guess about missing food.",
    )
    .check();
  await recipient2
    .getByRole("button", { name: "Record known physical outcome", exact: true })
    .click();
  await saved(recipient2, "Physical outcome recorded.");
  let record = (await get(recipient2, `allocations/${allocationId}`)).record;
  const original = record.recovery.custody_history.find(
    (report) => report.active && report.kind === "rejected_at_site",
  );
  assert.equal(original.quantity, "2");
  assert.equal(original.transferable_quantity, "2");
  assert.equal(original.can_confirm_disposal, true);
  assert.equal(original.can_confirm_return, false);
  assert.equal(record.recovery.accounted_quantity, "2");

  ui.setStep(
    "Kitchen confirms one actual return linked to the original rejection",
  );
  await open(kitchen, `/allocations/${allocationId}`);
  let kitchenRecord = (await get(kitchen, `allocations/${allocationId}`))
    .record;
  const kitchenRejection = kitchenRecord.recovery.custody_history.find(
    (report) => report.id === original.id,
  );
  assert.equal(kitchenRejection.can_confirm_return, true);
  assert.equal(kitchenRejection.can_confirm_disposal, false);
  await kitchen
    .getByText("Physical reports and corrections", { exact: true })
    .click();
  await kitchen
    .locator("summary")
    .filter({ hasText: "Confirm rejected food returned to this kitchen" })
    .click();
  assert.equal(
    await kitchen
      .locator(`#rejection-returned_to_kitchen-${original.id}-quantity`)
      .getAttribute("max"),
    null,
    "An actual later return is not capped by the expected remainder.",
  );
  await kitchen
    .locator(`#rejection-returned_to_kitchen-${original.id}-quantity`)
    .fill("1");
  await kitchen
    .locator(`#rejection-returned_to_kitchen-${original.id}-note`)
    .fill(
      "One of the two rejected boxes physically arrived back at the kitchen and is held separately from usable food.",
    );
  await kitchen
    .getByLabel(
      "This rejected food physically arrived at our kitchen and is kept separate from usable food.",
    )
    .check();
  await kitchen
    .getByRole("button", {
      name: "Record actual return to kitchen",
      exact: true,
    })
    .click();
  await saved(kitchen, "Rejected-food follow-up recorded.");
  kitchenRecord = (await get(kitchen, `allocations/${allocationId}`)).record;
  assert.equal(kitchenRecord.received_quantity, "2");
  assert.equal(
    kitchenRecord.recovery.accounted_quantity,
    "2",
    "A rejection and its later return cannot count as two separate boxes.",
  );
  assert.equal(kitchenRecord.recovery.rejected_quantity, "1");
  assert.equal(kitchenRecord.recovery.returned_quantity, "1");
  assert.equal(
    kitchenRecord.recovery.custody_history.find(
      (report) => report.id === original.id,
    ).quantity,
    "2",
  );
  const returned = kitchenRecord.recovery.custody_history.find(
    (report) => report.active && report.kind === "returned",
  );
  assert.equal(returned.from_custody_id, original.id);
  assert.equal(returned.agreement_issue, "");
  let food = (await get(kitchen, `offers/${offerId}`)).record;
  assert.equal(food.quarantined_quantity, "1");
  assert.equal(food.stock_projection.usable_on_hand_quantity, "0");
  assert.equal(food.available_quantity, "0");

  ui.setStep(
    "Receiving team records linked disposal, loses the response and recovers the same saved result",
  );
  await open(recipient2, `/allocations/${allocationId}`);
  await recipient2
    .getByText("Physical reports and corrections", { exact: true })
    .click();
  await recipient2
    .locator("summary")
    .filter({ hasText: "Record disposal of rejected food at this site" })
    .click();
  await recipient2
    .locator(`#rejection-disposed_at_recipient-${original.id}-quantity`)
    .fill("1");
  await recipient2
    .locator(`#rejection-disposed_at_recipient-${original.id}-note`)
    .fill(
      "Our receiving team physically disposed of the remaining rejected box at Riverside. It never became an accepted meal.",
    );
  await recipient2
    .getByLabel(
      "Our receiving team physically disposed of this rejected food at this site.",
    )
    .check();
  let lost = false;
  await recipient2.route("**/allfedo/api/commands", async (route) => {
    const body = route.request().postDataJSON();
    if (
      !lost &&
      body.action === "transfer_rejected" &&
      body.payload.outcome === "disposed_at_recipient"
    ) {
      const response = await route.fetch();
      assert.equal(response.ok(), true);
      lost = true;
      await route.abort("failed");
    } else await route.continue();
  });
  await recipient2
    .getByRole("button", {
      name: "Record actual disposal at this site",
      exact: true,
    })
    .click();
  await recipient2
    .getByRole("heading", {
      name: "An earlier change needs checking",
      exact: true,
    })
    .waitFor();
  await recipient2.reload({ waitUntil: "domcontentloaded" });
  await recipient2
    .getByRole("heading", {
      name: "An earlier change needs checking",
      exact: true,
    })
    .waitFor();
  await recipient2
    .locator("#recovery")
    .getByRole("button", { name: "Check the saved result", exact: true })
    .click();
  await recipient2
    .getByRole("heading", {
      name: "An earlier change needs checking",
      exact: true,
    })
    .waitFor({ state: "hidden" });
  assert.equal(
    new URL(recipient2.url()).hash,
    `#/allocations/${allocationId}`,
    "A recipient's saved result must reopen its authorized collection, not a restricted food-offer page.",
  );
  await recipient2.unroute("**/allfedo/api/commands");
  record = (await get(recipient2, `allocations/${allocationId}`)).record;
  assert.equal(record.received_quantity, "2");
  assert.equal(record.recovery.accounted_quantity, "2");
  assert.equal(record.recovery.rejected_quantity, "0");
  assert.equal(record.recovery.returned_quantity, "1");
  assert.equal(record.recovery.disposed_quantity, "1");
  const preserved = record.recovery.custody_history.find(
    (report) => report.id === original.id,
  );
  assert.equal(preserved.active, 1);
  assert.equal(preserved.quantity, "2");
  assert.equal(preserved.transferable_quantity, "0");
  assert.equal(
    preserved.can_confirm_disposal,
    true,
    "Reporting authority remains even when no movement remains expected.",
  );
  const disposal = record.recovery.custody_history.filter(
    (report) => report.active && report.kind === "recipient_disposed",
  );
  assert.equal(
    disposal.length,
    1,
    "Lost-response recovery cannot duplicate a linked disposal.",
  );
  assert.equal(disposal[0].from_custody_id, original.id);
  assert.equal(disposal[0].agreement_issue, "");
  await recipient2
    .getByText("Physical reports and corrections", { exact: true })
    .click();
  await shot(recipient2, "rejected-food-linked-history-mobile");

  ui.setStep(
    "Partners settle only the unfulfilled promise after the physical outcomes are known",
  );
  await open(coordinator, `/allocations/${allocationId}`);
  await coordinator
    .getByText("Change the commitment or confirm new instructions", {
      exact: true,
    })
    .click();
  await coordinator.locator("#change-new-quantity").fill("2");
  await coordinator
    .locator("#change-reason")
    .fill(
      "Two meals accepted. Of the two rejected boxes, one returned to the kitchen and one was disposed of at the receiving site. Ask the receiver to confirm a two-meal commitment and its full need.",
    );
  await coordinator
    .getByRole("button", { name: "Request partner confirmation", exact: true })
    .click();
  await saved(coordinator, "Change proposed.");
  await open(recipient2, `/allocations/${allocationId}`);
  await recipient2.locator("#change-answer").selectOption("agree");
  await recipient2.locator("#change-need-total").fill("30");
  await recipient2
    .locator("#change-response-note")
    .fill(
      "Our full need remains 30 for this window, including earlier accepted food. This collection provided two accepted meals.",
    );
  await recipient2
    .getByRole("button", { name: "Save my response", exact: true })
    .click();
  await saved(recipient2, "Your response is recorded.");
  record = (await get(recipient2, `allocations/${allocationId}`)).record;
  assert.equal(record.quantity, "2");
  assert.equal(record.received_quantity, "2");
  assert.equal(record.recovery.original_promise_quantity, "4");
  assert.equal(record.recovery.accounted_quantity, "2");
  assert.equal(record.recovery.physical_unknown_quantity, "0");
  assert.equal(record.state, "partial_closed");

  ui.setStep(
    "Kitchen disposes of the returned box without reopening food stock",
  );
  await open(kitchen, `/offers/${offerId}`);
  await kitchen
    .getByText("Dispose of returned food kept in quarantine", { exact: true })
    .click();
  await kitchen.locator("#quarantine-quantity").fill("1");
  await kitchen
    .locator("#quarantine-note")
    .fill(
      "The one returned rejected box was physically disposed of by the kitchen. It was never put back into usable stock.",
    );
  await kitchen
    .getByLabel(
      "Our team physically disposed of this quarantined food. It has not gone back into available stock.",
    )
    .check();
  await kitchen
    .getByRole("button", { name: "Record quarantine disposal", exact: true })
    .click();
  await saved(kitchen, "Quarantine disposal recorded.");
  food = (await get(kitchen, `offers/${offerId}`)).record;
  assert.equal(food.quarantined_quantity, "0");
  assert.equal(food.stock_projection.usable_on_hand_quantity, "0");
  assert.equal(food.available_quantity, "0");
  record = (await get(kitchen, `allocations/${allocationId}`)).record;
  assert.equal(record.received_quantity, "2");
  assert.equal(record.recovery.accounted_quantity, "2");
  await open(kitchen, `/allocations/${allocationId}`);
  await kitchen
    .getByText("Physical reports and corrections", { exact: true })
    .click();
  await shot(kitchen, "rejected-food-final-history");
  ui.results.push(
    "Linked rejected-food follow-up: two accepted/two rejected; one later return and one recipient-site disposal preserve the original rejection and account for only two boxes. Reload recovery creates one disposal and reopens the recipient case. Kitchen quarantine disposal restores no usable stock or accepted meals.",
  );
}
