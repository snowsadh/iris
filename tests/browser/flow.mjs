/** Real native browser journey. Uses isolated invited accounts; never calls a paid planning model. */
import assert from "node:assert/strict";
import { readFile, mkdir } from "node:fs/promises";
import { chromium } from "playwright";
import { onwardJourney } from "./redirect.mjs";

const accountPath = process.env.ALLFEDO_BROWSER_ACCOUNTS;
if (!accountPath) {
  console.error(
    "Set ALLFEDO_BROWSER_ACCOUNTS to a private JSON file containing accounts for the four native roles.",
  );
  process.exit(1);
}
const configuration = JSON.parse(await readFile(accountPath, "utf8"));
const accounts = configuration.accounts;
const base = new URL(
  process.env.ALLFEDO_BASE_URL ||
    configuration.base_url ||
    "http://127.0.0.1:52773/allfedo/",
);
const output =
  process.env.ALLFEDO_BROWSER_OUTPUT || "/tmp/allfedo-browser-check";
const secrets = Object.values(accounts).flatMap((account) => [
  account.username,
  account.password,
]);
const clean = (message) =>
  secrets.reduce(
    (text, secret) =>
      secret ? text.replaceAll(secret, "[private account]") : text,
    String(message),
  );
const browser = await chromium.launch({
  headless: true,
  ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE
    ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE }
    : {}),
});
const pages = {};
const results = [];
let step = "Starting native sessions";
const token = Date.now().toString(36);
const foodDescription = `Sealed vegetable rice · browser check ${token}`;

async function login(role, expectedRole = role) {
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1050 },
  });
  const page = await context.newPage();
  page.on("pageerror", (error) =>
    results.push({ browser_error: clean(error.message) }),
  );
  await page.goto(base.href);
  await page.locator('[name="IRISUsername"]').fill(accounts[role].username);
  await page.locator('[name="IRISPassword"]').fill(accounts[role].password);
  await page.locator('[name="IRISLogin"]').click();
  await page.locator("#app .header").waitFor({ timeout: 30000 });
  const session = await get(page, "session");
  assert.equal(
    session.user.role,
    expectedRole,
    "The native session must own the role.",
  );
  pages[role] = page;
  return page;
}

async function get(page, resource) {
  return page.evaluate(async (path) => {
    const response = await fetch(`/allfedo/api/${path}`, {
      credentials: "same-origin",
      cache: "no-store",
    });
    const result = await response.json();
    if (!response.ok || result.ok === false)
      throw new Error(result.error?.message || "Native read failed.");
    return result;
  }, resource);
}

async function open(page, path) {
  step = `Opening ${path}`;
  if (new URL(page.url()).hash === `#${path}`)
    await page
      .getByRole("button", { name: "Read updates", exact: true })
      .click();
  else await page.goto(new URL(`#${path}`, base).href);
  await page.waitForFunction((expected) => {
    const screen = document.getElementById("screen");
    return (
      screen?.dataset.route === expected.split("?")[0] &&
      !screen.hasAttribute("aria-busy")
    );
  }, path);
  if (!(await page.locator("#screen h1").count()))
    throw new Error(await page.locator("#screen").innerText());
}

async function shot(page, name) {
  assert.equal(
    await page.locator('input[type="password"]').count(),
    0,
    "Never screenshot a credential form.",
  );
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: `${output}/${name}.png`, fullPage: true });
}

function clock(iso, minutes) {
  return new Date(new Date(iso).getTime() + minutes * 60000)
    .toISOString()
    .slice(0, 16);
}

async function saveSite(page, name, address, entrance) {
  await open(page, "/site");
  await page.locator("#site-name").fill(name);
  await page.locator("#site-address").fill(address);
  await page.locator("#site-entrance").fill(entrance);
  await page.locator("#site-time-zone").fill("UTC");
  await page.locator("#site-phone").fill("+1 202 555 0142");
  await page
    .getByLabel("I confirm these are the correct location and access details.")
    .check();
  await page
    .getByRole("button", { name: "Save partner location", exact: true })
    .click();
  await page.waitForFunction(() => !location.hash.startsWith("#/site"));
  await page.locator("#screen[aria-busy]").waitFor({ state: "hidden" });
}

async function enterFood(page, description) {
  const server = await get(page, "session");
  await open(page, "/offers/new");
  await page.locator("#food-description").fill(description);
  await page.locator("#food-quantity").fill("40");
  await page.locator("#food-holding").selectOption("chilled");
  await page.locator("#handling-until").fill(clock(server.now, 90));
  await page.locator("#food-ready").fill(clock(server.now, -2));
  await page.locator("#food-cutoff").fill(clock(server.now, 60));
  await page
    .locator("#food-packaging")
    .fill("8 carry cartons, each containing 5 sealed meal boxes.");
  await page.locator('input[name="present"][value="milk"]').check();
  await page
    .getByText("Record allergens you checked and found absent", { exact: true })
    .click();
  await page.locator('input[name="absent"][value="peanut"]').check();
  await page
    .getByLabel(
      "These details reflect what our kitchen can confirm. I will report changes before collection.",
    )
    .check();
}

try {
  await mkdir(output, { recursive: true });
  const kitchen = await login("kitchen");
  const recipient = await login("recipient");
  const coordinator = await login("coordinator");
  const collector = await login("collector");
  if (!accounts.recipient2)
    throw new Error(
      "Complete browser checks need a second receiving account. Run npm run test:browser for a fresh five-account fixture.",
    );
  const recipient2 = await login("recipient2", "recipient");
  results.push(
    "Five independent native sessions cover four roles and two receiving teams.",
  );
  const rendered = await kitchen.evaluate(async () => {
    const { el, append, checkedAbsent, custody } = await import(
      "/allfedo/render.js"
    );
    const { occurredAt, actionForm } = await import("/allfedo/forms.js");
    const submitted = [];
    const agreement = actionForm({
      title: "Guarded agreement",
      submit: "Save",
      fields: [],
      onSubmit: () => submitted.push("agreement"),
    });
    const physical = actionForm({
      title: "Physical fact",
      submit: "Record",
      fields: [],
      physicalReport: true,
      onSubmit: () => submitted.push("physical"),
    });
    for (const form of [agreement, physical]) {
      form.dataset.stale = "1";
      form.dispatchEvent(new Event("submit", { cancelable: true }));
    }
    const node = el(
      "div",
      {},
      false,
      true,
      null,
      undefined,
      0,
      "<img src=x onerror=alert(1)>",
    );
    append(node, false, [" source text"]);
    const now = () => "2026-11-09T12:00:00.000Z";
    const report = new FormData();
    const defaultTime = occurredAt(report, "Europe/London", now);
    report.set("occurred", "2026-11-09T11:45");
    const lateTime = occurredAt(report, "Europe/London", now);
    report.set("occurred", "2026-11-09T12:01");
    let futureRejected = false;
    try {
      occurredAt(report, "Europe/London", now);
    } catch {
      futureRejected = true;
    }
    const unknown = custody({
      state: "closed_unconfirmed",
      quantity: "18",
      collected_quantity: "20",
      received_quantity: "18",
      recovery: {
        original_promise_quantity: "20",
        physical_unknown_quantity: "2",
        closed_unknown_quantity: "2",
        unhanded_quantity: "0",
        lost_quantity: "0",
        disposed_quantity: "0",
        rejected_quantity: "0",
        returned_quantity: "0",
        cannot_arrive_quantity: "0",
        unmatched_report_quantity: "0",
      },
    });
    return {
      text: node.textContent,
      images: node.querySelectorAll("img").length,
      submitted,
      defaultTime,
      lateTime,
      futureRejected,
      absent: checkedAbsent({
        present_allergens: ["Milk"],
        assessed_allergens: ["milk", "peanut"],
      }),
      custody: unknown.textContent,
    };
  });
  assert.equal(rendered.text, "0<img src=x onerror=alert(1)> source text");
  assert.equal(rendered.images, 0);
  assert.deepEqual(
    rendered.submitted,
    ["physical"],
    "Changed instructions block a new agreement but cannot erase an actual physical report.",
  );
  assert.equal(rendered.defaultTime, "2026-11-09T12:00:00.000Z");
  assert.equal(rendered.lateTime, "2026-11-09T11:45:00.000Z");
  assert.equal(rendered.futureRejected, true);
  assert.deepEqual(rendered.absent, ["peanut"]);
  assert.match(rendered.custody, /2 meal boxes not yet accounted for/);
  assert.match(rendered.custody, /no longer count as expected arrivals/);
  assert.doesNotMatch(rendered.custody, /Count matches/);
  results.push(
    "Shared rendering omits boolean placeholders, keeps zero counts and renders source text without HTML execution.",
  );

  let offerId;
  let needId;
  let allocation;
  if (process.env.ALLFEDO_BROWSER_RESUME_ALLOCATION) {
    allocation = (
      await get(
        recipient,
        `allocations/${process.env.ALLFEDO_BROWSER_RESUME_ALLOCATION}`,
      )
    ).record;
    assert.equal(
      allocation.state,
      "collected",
      "Resume the actual handoff that still needs a receiving count.",
    );
    offerId = allocation.offer.id;
    needId = allocation.need.id;
    results.push(
      "Resuming the existing saved collection after its actual named trip and 28-box handoff; no replacement collector or invented state.",
    );
  } else {
    await saveSite(
      kitchen,
      "Harbor Kitchen",
      "14 Harbor Street",
      "Rear service door",
    );
    await saveSite(
      recipient,
      "Westside Community Centre",
      "28 Westside Avenue",
      "Reception desk",
    );
    await enterFood(kitchen, foodDescription);
    await kitchen
      .getByRole("button", {
        name: "Send food details for review",
        exact: true,
      })
      .click();
    await kitchen.waitForURL(/#\/offers\/\d+$/);
    offerId = kitchen.url().match(/#\/offers\/(\d+)$/)[1];
    await kitchen.locator("#screen[aria-busy]").waitFor({ state: "hidden" });
    const food = (await get(kitchen, `offers/${offerId}`)).record;
    assert.equal(food.current_quantity, "40");
    assert.equal(
      food.packaging,
      "8 carry cartons, each containing 5 sealed meal boxes.",
    );
    assert.equal(food.site.entrance, "Rear service door");
    results.push(
      "Kitchen submission, packaging, partner access and food facts persist in IRIS.",
    );

    const existing = (await get(recipient, "needs")).records.find(
      (need) =>
        Number(need.held_quantity) === 0 &&
        Number(need.committed_quantity) === 0,
    );
    const server = await get(recipient, "session");
    await open(
      recipient,
      existing ? `/needs/${existing.id}/edit` : "/needs/new",
    );
    await recipient.locator("#need-quantity").fill("50");
    await recipient.locator("#need-receiving-from").fill(clock(server.now, -2));
    await recipient.locator("#need-receiving").fill(clock(server.now, 120));
    await recipient.locator("#need-confirmed").fill(clock(server.now, 110));
    await recipient
      .locator('input[name="accepted_holding"][value="chilled"]')
      .check();
    await recipient
      .locator('input[name="excluded_allergens"][value="peanut"]')
      .check();
    await recipient
      .getByLabel(
        "I confirm this total and the receiving requirements for our team.",
      )
      .check();
    await recipient
      .getByRole("button", {
        name: existing ? "Update receiving need" : "Confirm receiving need",
        exact: true,
      })
      .click();
    await recipient.waitForURL(/#\/needs\/\d+$/);
    needId = recipient.url().match(/#\/needs\/(\d+)$/)[1];
    await recipient.locator("#screen[aria-busy]").waitFor({ state: "hidden" });

    await open(coordinator, `/offers/${offerId}/plan`);
    await coordinator.locator(`#plan-${needId}`).fill("35");
    await coordinator
      .locator("#plan-reason")
      .fill(
        "Westside confirmed chilled handling and a current need. The kitchen assessed the excluded peanut allergen and found it absent.",
      );
    await coordinator
      .getByRole("button", { name: "Review this draft", exact: true })
      .click();
    await coordinator
      .getByRole("heading", {
        name: "Review these food invitations",
        exact: true,
      })
      .waitFor();
    await shot(coordinator, "coordinator-review");
    assert.equal(
      (await get(kitchen, `offers/${offerId}`)).record.held_quantity,
      "0",
      "Review must not create a hold.",
    );
    await coordinator
      .getByLabel(
        "I have reviewed the quantities, food requirements and receiving windows.",
      )
      .check();
    await coordinator
      .getByRole("button", { name: "Send these invitations", exact: true })
      .click();
    await coordinator.waitForURL(/#\/allocations\?/);
    allocation = (await get(coordinator, `allocations?offer_id=${offerId}`))
      .records[0];
    assert.equal(allocation.state, "held");
    assert.equal(allocation.quantity, "35");
    results.push(
      "Manual review creates no hold; explicit send creates the actual 35-box native invitation.",
    );

    await open(recipient, `/allocations/${allocation.id}`);
    await recipient.locator("#accept-quantity").fill("30");
    await recipient
      .getByLabel(
        "I confirm our team can receive this food under the recorded requirements.",
      )
      .check();
    await recipient
      .getByRole("button", { name: "Reserve these meal boxes", exact: true })
      .click();
    await recipient.locator("#collector-choice").waitFor();
    assert.equal(
      Boolean(
        (await get(recipient, `allocations/${allocation.id}`)).record
          .transport_confirmed,
      ),
      false,
    );
    await recipient
      .locator("#collector-choice")
      .selectOption(String(accounts.collector.actor_id));
    await recipient
      .getByRole("button", { name: "Assign collector", exact: true })
      .click();
    await recipient
      .getByRole("status")
      .filter({ hasText: "Collector assigned." })
      .waitFor();
    results.push(
      "Partial recipient acceptance reserves 30 and assigns an approved collector without inventing transport.",
    );

    await open(collector, `/allocations/${allocation.id}`);
    const tripClock = await get(collector, "session");
    await collector.locator("#trip-pickup").fill(clock(tripClock.now, 2));
    await collector.locator("#trip-arrival").fill(clock(tripClock.now, 30));
    await collector.locator("#trip-capacity").fill("30");
    await collector.locator('input[name="handling"]').check();
    await collector
      .getByRole("button", { name: "Confirm my trip", exact: true })
      .click();
    await collector
      .getByRole("status")
      .filter({ hasText: "Your trip is agreed." })
      .waitFor();
    assert.equal(
      (await get(collector, `allocations/${allocation.id}`)).record.state,
      "ready",
    );
    await shot(collector, "collector-trip");

    await open(kitchen, `/allocations/${allocation.id}`);
    await kitchen.locator("#handoff-count").fill("28");
    await kitchen
      .locator("#handoff-note")
      .fill(
        "Two promised boxes were not at the loading point. Their outcome still needs a count check.",
      );
    await kitchen
      .getByLabel(
        "The named collector is here and this quantity has physically changed hands.",
      )
      .check();
    await shot(kitchen, "kitchen-handoff");
    await kitchen
      .getByRole("button", { name: "Record actual handoff", exact: true })
      .click();
    await kitchen
      .getByRole("status")
      .filter({ hasText: "The kitchen handoff is recorded." })
      .waitFor();
    const handed = (await get(kitchen, `allocations/${allocation.id}`)).record;
    assert.equal(handed.collected_quantity, "28");
    assert.equal(
      handed.recovery.custody_history.find(
        (report) => report.active && report.kind === "handoff",
      )?.agreement_issue,
      "",
      "The normal in-window handoff must not hide an agreement or timing warning.",
    );
  }
  await open(recipient, `/allocations/${allocation.id}`);
  await recipient.locator("#receipt-count").fill("27");
  await recipient
    .locator("#receipt-note")
    .fill(
      "27 accepted. One handed-over box arrived damaged; two promised boxes were not handed over. Coordinator follow-up remains open.",
    );
  await recipient
    .getByLabel("I have counted the food at our receiving point.")
    .check();
  await recipient
    .getByRole("button", { name: "Record receiving count", exact: true })
    .click();
  await recipient
    .getByRole("status")
    .filter({ hasText: "Receiving count recorded." })
    .waitFor();
  const received = (await get(recipient, `allocations/${allocation.id}`))
    .record;
  assert.equal(received.state, "receipt_issue");
  assert.equal(received.received_quantity, "27");
  for (const kind of ["handoff", "receipt"]) {
    const report = received.recovery.custody_history.find(
      (item) => item.active && item.kind === kind,
    );
    assert.ok(report, `The actual ${kind} report must be present.`);
    assert.equal(
      report.agreement_issue,
      "",
      `The normal in-window ${kind} must not hide an agreement or timing warning.`,
    );
  }
  assert.equal(received.unresolved_quantity, "3");
  const finalNeed = (await get(recipient, `needs/${needId}`)).record;
  assert.equal(finalNeed.committed_quantity, "30");
  assert.equal(finalNeed.remaining_quantity, "20");
  await shot(recipient, "receiving-count");
  await recipient.setViewportSize({ width: 390, height: 844 });
  assert.equal(
    await recipient.evaluate(
      () => document.documentElement.scrollWidth > innerWidth,
    ),
    false,
  );
  await shot(recipient, "receiving-mobile");
  results.push(
    "Actual collector confirmation, 28-box handoff and 27-box receipt leave three unresolved and receiving capacity unchanged by receipt.",
  );

  step = "Recording the known rejected box and actual kitchen stock";
  await recipient
    .getByText("Record a known outcome for food not accepted", { exact: true })
    .click();
  await recipient.locator("#outcome-kind").selectOption("rejected_at_site");
  await recipient.locator("#outcome-quantity").fill("1");
  await recipient
    .locator("#outcome-note")
    .fill(
      "One damaged box is rejected and kept separately at this receiving site. It has not been returned or disposed of.",
    );
  await recipient
    .getByLabel(
      "I can confirm this physical outcome. This is not a guess about missing food.",
    )
    .check();
  await recipient
    .getByRole("button", { name: "Record known physical outcome", exact: true })
    .click();
  await recipient
    .getByRole("status")
    .filter({ hasText: "Physical outcome recorded." })
    .waitFor();
  await open(kitchen, `/offers/${offerId}`);
  await kitchen
    .getByText("Report a changed physical count", { exact: true })
    .click();
  await kitchen.locator("#stock-quantity").fill("12");
  await kitchen
    .locator("#stock-note")
    .fill(
      "Counted all 12 boxes still at the kitchen. The two boxes absent from the loading point remained in the cold room. No returned food is included.",
    );
  await kitchen
    .getByRole("button", { name: "Report the changed count", exact: true })
    .click();
  await kitchen
    .getByRole("status")
    .filter({ hasText: "Changed count recorded." })
    .waitFor();
  const counted = (await get(kitchen, `offers/${offerId}`)).record;
  assert.equal(counted.stock_count.on_hand_quantity, "12");
  assert.equal(counted.stock_projection.usable_on_hand_quantity, "12");
  step = "Proposing an explicit smaller commitment";
  await open(coordinator, `/allocations/${allocation.id}`);
  await coordinator
    .getByText("Change the commitment or confirm new instructions", {
      exact: true,
    })
    .click();
  await coordinator.locator("#change-new-quantity").fill("27");
  await coordinator
    .locator("#change-reason")
    .fill(
      "27 boxes accepted; one rejected and kept at the receiving site. The kitchen counted the two unhanded boxes still there. Ask both partners to agree a 27-box commitment.",
    );
  await coordinator
    .getByRole("button", { name: "Request partner confirmation", exact: true })
    .click();
  await coordinator
    .getByRole("status")
    .filter({ hasText: "Change proposed." })
    .waitFor();
  let changing = (await get(coordinator, `allocations/${allocation.id}`))
    .record;
  assert.equal(
    changing.quantity,
    "30",
    "A proposal cannot cancel the old promise.",
  );
  assert.equal(changing.recovery.change.state, "awaiting_response");
  await open(recipient, `/allocations/${allocation.id}`);
  await recipient.locator("#change-answer").selectOption("agree");
  await recipient.locator("#change-need-total").fill("50");
  await recipient
    .locator("#change-response-note")
    .fill(
      "Our full need is still 50 meal boxes for this window, including the 27 accepted. We agree this collection now supplies 27.",
    );
  await recipient
    .getByRole("button", { name: "Save my response", exact: true })
    .click();
  await recipient
    .getByRole("status")
    .filter({ hasText: "Your response is recorded." })
    .waitFor();
  changing = (await get(coordinator, `allocations/${allocation.id}`)).record;
  assert.equal(
    changing.quantity,
    "30",
    "Kitchen confirmation remains required for unhanded stock release.",
  );
  await open(kitchen, `/allocations/${allocation.id}`);
  await kitchen.locator("#change-answer").selectOption("agree");
  await kitchen
    .locator("#change-response-note")
    .fill(
      "Our latest saved physical count confirms 12 boxes are here. We agree to release the two unhanded boxes from this promise; no food was returned by this change.",
    );
  await kitchen
    .getByRole("button", { name: "Save my response", exact: true })
    .click();
  await kitchen
    .getByRole("status")
    .filter({ hasText: "Your response is recorded." })
    .waitFor();
  const recovered = (await get(kitchen, `allocations/${allocation.id}`)).record;
  assert.equal(recovered.recovery.change.state, "applied");
  assert.equal(recovered.quantity, "27");
  assert.equal(recovered.recovery.original_promise_quantity, "30");
  assert.equal(recovered.recovery.rejected_quantity, "1");
  assert.equal(recovered.recovery.physical_unknown_quantity, "0");
  assert.equal(recovered.state, "partial_closed");
  const afterChange = (await get(recipient, `needs/${needId}`)).record;
  assert.equal(afterChange.requested_quantity, "50");
  assert.equal(afterChange.committed_quantity, "27");
  assert.equal(afterChange.remaining_quantity, "23");
  await shot(kitchen, "recovery-agreed");
  step = "Correcting a physical report without changing its actual time";
  const earlierHandoff = recovered.recovery.custody_history.find(
    (report) => report.active && report.kind === "handoff",
  );
  assert.equal(earlierHandoff.can_correct, true);
  await kitchen
    .getByText("Physical reports and corrections", { exact: true })
    .click();
  await kitchen
    .getByText("Correct this report", { exact: true })
    .first()
    .click();
  await kitchen.locator(`#correction-${earlierHandoff.id}-quantity`).fill("28");
  await kitchen
    .locator(`#correction-${earlierHandoff.id}-note`)
    .fill(
      "Clarified loading-point record: 28 boxes physically changed hands. The two remaining promised boxes were later found in the cold room. Quantity and actual time are unchanged.",
    );
  await kitchen
    .getByLabel(
      "This replaces the earlier report with the actual count and time. It does not record another movement of food.",
    )
    .check();
  await kitchen
    .getByRole("button", { name: "Save correction for review", exact: true })
    .click();
  await kitchen
    .getByRole("status")
    .filter({ hasText: "Correction recorded for review." })
    .waitFor();
  const corrected = (await get(kitchen, `allocations/${allocation.id}`)).record;
  assert.equal(
    corrected.collected_quantity,
    "28",
    "A correction cannot double-count a handoff.",
  );
  const currentHandoff = corrected.recovery.custody_history.find(
    (report) => report.active && report.kind === "handoff",
  );
  assert.equal(
    currentHandoff.occurred_at,
    earlierHandoff.occurred_at,
    "Quantity-only correction preserves the actual source timestamp, including fractions.",
  );
  assert.equal(
    corrected.recovery.custody_history.find(
      (report) => report.id === earlierHandoff.id,
    ).active,
    0,
  );
  assert.equal(currentHandoff.supersedes_id, earlierHandoff.id);
  assert.equal(
    corrected.recovery.original_trip.context_key,
    recovered.recovery.original_trip.context_key,
  );
  results.push(
    "A real physical-report correction keeps the original source visible, preserves its exact timestamp and original trip, and does not double-count the handoff.",
  );
  const needAfterCorrection = (await get(recipient, `needs/${needId}`)).record;
  assert.equal(needAfterCorrection.state, "review_required");
  assert.equal(
    needAfterCorrection.remaining_quantity,
    "0",
    "A physical correction cannot silently reopen unconfirmed receiving capacity.",
  );
  await open(recipient, `/needs/${needId}/edit`);
  await recipient
    .getByLabel(
      "I confirm this total and the receiving requirements for our team.",
    )
    .check();
  await recipient
    .getByRole("button", { name: "Update receiving need", exact: true })
    .click();
  await recipient.waitForURL(/#\/needs\/\d+$/);
  await recipient.locator("#screen[aria-busy]").waitFor({ state: "hidden" });
  const reconfirmed = (await get(recipient, `needs/${needId}`)).record;
  assert.equal(reconfirmed.state, "open");
  assert.equal(reconfirmed.requested_quantity, "50");
  assert.equal(reconfirmed.committed_quantity, "27");
  assert.equal(reconfirmed.remaining_quantity, "23");
  results.push(
    "Correcting physical facts pauses receiving capacity; the actual receiving contact explicitly re-confirms the full50 before the remaining23 can receive new invitations.",
  );
  await open(coordinator, `/offers/${offerId}`);
  await coordinator
    .getByLabel(
      "I have reviewed the actual count, changed promises and partner confirmations.",
    )
    .check();
  await coordinator
    .getByRole("button", { name: "Check and resume invitations", exact: true })
    .click();
  await coordinator
    .getByRole("status")
    .filter({ hasText: "Invitations resumed" })
    .waitFor();
  const resumed = (await get(kitchen, `offers/${offerId}`)).record;
  assert.equal(resumed.state, "open");
  assert.equal(resumed.available_quantity, "12");
  assert.equal(
    resumed.stock_projection.usable_on_hand_quantity,
    "12",
    "Releasing a promise cannot invent physically returned stock.",
  );
  results.push(
    "Known rejected food stays at the receiving site; actual kitchen count and both partner replies explicitly change30 to27, keep original30, retain physical outcomes and leave23 of the full50 still needed. Native checks safely resume invitations without inventing returned stock.",
  );

  const recoveryDescription = `Recovery-check meal boxes ${token}`;
  await enterFood(kitchen, recoveryDescription);
  let lost = false;
  await kitchen.route("**/allfedo/api/commands", async (route) => {
    const body = route.request().postDataJSON();
    if (
      !lost &&
      body.action === "create_offer" &&
      body.payload.description === recoveryDescription
    ) {
      const response = await route.fetch();
      assert.equal(response.ok(), true);
      lost = true;
      await route.abort("failed");
    } else await route.continue();
  });
  await kitchen
    .getByRole("button", { name: "Send food details for review", exact: true })
    .click();
  await kitchen
    .getByRole("heading", {
      name: "An earlier change needs checking",
      exact: true,
    })
    .waitFor();
  await kitchen.reload();
  await kitchen
    .getByRole("heading", {
      name: "An earlier change needs checking",
      exact: true,
    })
    .waitFor();
  await kitchen
    .locator("#recovery")
    .getByRole("button", { name: "Check the saved result", exact: true })
    .click();
  await kitchen
    .getByRole("heading", {
      name: "An earlier change needs checking",
      exact: true,
    })
    .waitFor({ state: "hidden" });
  const recoveryMatches = (await get(kitchen, "offers")).records.filter(
    (record) => record.description === recoveryDescription,
  );
  assert.equal(
    recoveryMatches.length,
    1,
    "Lost response + reload + explicit retry must not duplicate a saved offer.",
  );
  assert.equal(
    await kitchen.evaluate(
      () =>
        Object.keys(sessionStorage).filter((key) =>
          key.startsWith("allfedo:in-flight:"),
        ).length,
    ),
    0,
  );
  await kitchen.unroute("**/allfedo/api/commands");
  results.push(
    "A real command response lost after server save survives reload and reuses its original request identity: one saved offer.",
  );

  await onwardJourney({
    pages,
    get,
    open,
    shot,
    clock,
    saveSite,
    enterFood,
    token,
    collectorId: String(accounts.collector.actor_id),
    results,
    setStep(value) {
      step = value;
    },
  });

  assert.equal(
    results.some(
      (result) => typeof result === "object" && result.browser_error,
    ),
    false,
    "Browser must not raise JavaScript errors.",
  );
  console.log(
    JSON.stringify(
      { passed: true, checks: results, screenshots: output },
      null,
      2,
    ),
  );
} catch (error) {
  console.error(clean(`${step}: ${error.message}`));
  console.error(JSON.stringify({ completed: results }, null, 2));
  for (const [role, page] of Object.entries(pages)) {
    if (
      (await page
        .locator("#app .header")
        .isVisible()
        .catch(() => false)) &&
      !(await page.locator('input[type="password"]').count())
    ) {
      console.error(
        clean(
          `${role} ${new URL(page.url()).hash}: ${(
            await page
              .locator("#screen")
              .innerText()
              .catch(() => "")
          ).slice(0, 2000)}`,
        ),
      );
      await page.screenshot({
        path: `${output}/failure-${role}.png`,
        fullPage: true,
      });
    }
  }
  process.exitCode = 1;
} finally {
  await browser.close();
}
