// Browser checks for the interface preview only. No IRIS or live service is tested.
const assert = require("node:assert/strict");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { chromium } = require(
  process.env.FOOD_PREVIEW_PLAYWRIGHT || "playwright",
);

async function main() {
  const browser = await chromium.launch({
    headless: true,
    ...(process.env.FOOD_PREVIEW_BROWSER
      ? { executablePath: process.env.FOOD_PREVIEW_BROWSER }
      : {}),
  });
  try {
    const page = await browser.newPage({
      viewport: { width: 1280, height: 1000 },
    });
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    await page.goto(
      pathToFileURL(path.join(__dirname, "food-rescue.html")).href,
    );
    const role = (value) => page.locator("#role").selectOption(value);
    const state = () =>
      page.evaluate(() =>
        JSON.parse(sessionStorage.getItem("food-rescue-preview-v1")),
      );
    const text = () => page.locator("#app").innerText();

    async function post(quantity = 80) {
      await page
        .getByRole("button", { name: "Start over", exact: true })
        .click();
      await page.getByLabel("Number of meal boxes").fill(String(quantity));
      await page
        .getByText("These are sealed meal boxes.", { exact: false })
        .click();
      await page
        .getByRole("button", { name: /^Offer [0-9]+ meal boxes$/ })
        .click();
    }
    async function send() {
      await role("desk");
      await page.getByRole("button", { name: /^Send [0-9]+ offers?$/ }).click();
    }
    async function accept(id, quantity) {
      await role(id);
      if (quantity)
        await page
          .getByLabel("How many boxes can you take?")
          .fill(String(quantity));
      await page.getByText("Collection is agreed.", { exact: false }).click();
      await page.getByRole("button", { name: /^Accept [0-9]+ boxes$/ }).click();
    }
    async function collect(id, code) {
      await role("kitchen");
      const form = page.locator(
        `form[data-form="handoff"][data-partner="${id}"]`,
      );
      await form.locator("..").locator("summary").click();
      await form.locator('input[name="code"]').fill(code);
      await form.locator('input[type="checkbox"]').check();
      await form.getByRole("button", { name: /^Confirm handoff/ }).click();
    }

    // A suggestion and invitation must not become a confirmed reservation or receipt.
    await post();
    assert.match(await text(), /No pickup confirmed yet/);
    await send();
    assert.equal((await state()).requests.riverside.status, "offered");
    assert.equal((await state()).requests.riverside.received, null);
    await accept("riverside");
    await accept("bridge");
    assert.equal(
      await page.getByRole("button", { name: /^Received all/ }).count(),
      0,
    );
    await collect("riverside", "000000");
    assert.match(
      await page.locator("#notice").innerText(),
      /code does not match/,
    );
    assert.equal((await state()).requests.riverside.picked, false);
    const form = page.locator(
      'form[data-form="handoff"][data-partner="riverside"]',
    );
    await form.locator('input[name="code"]').fill("314159");
    await form.getByRole("button", { name: /^Confirm handoff/ }).click();
    await role("riverside");
    await page
      .getByRole("button", { name: "Received all 35 boxes", exact: true })
      .click();
    await collect("bridge", "271828");
    await role("bridge");
    await page
      .getByRole("button", { name: "Received all 45 boxes", exact: true })
      .click();
    await role("kitchen");
    assert.match(await text(), /The boxes have been received/);
    assert.equal(
      Object.values((await state()).requests).reduce(
        (sum, request) => sum + request.received,
        0,
      ),
      80,
    );
    await page.reload();
    assert.match(await text(), /The boxes have been received/);
    console.log(
      "PASS: complete case, code rejection, receipt ordering, and refresh recovery",
    );

    // Reject a plan exceeding stock. Taking fewer must release the difference.
    await post(60);
    await role("desk");
    await page.getByLabel("Boxes to offer").nth(1).fill("45");
    await page.getByRole("button", { name: /^Send [0-9]+ offers?$/ }).click();
    assert.match(
      await page.locator("#notice").innerText(),
      /Only 60 boxes remain/,
    );
    assert.deepEqual((await state()).requests, {});
    await post();
    await send();
    await accept("riverside", 20);
    await role("kitchen");
    assert.match(
      await page.locator(".balances").innerText(),
      /15\s+available to offer/,
    );
    await page
      .getByText("Stop offering the remaining 15 boxes", { exact: true })
      .click();
    await page
      .getByRole("button", { name: "Stop offering 15 boxes", exact: true })
      .click();
    assert.match(
      await page.locator(".balances").innerText(),
      /15\s+withdrawn from offer/,
    );
    assert.equal((await state()).requests.riverside.quantity, 20);
    console.log(
      "PASS: stock limit, partial acceptance, and visible withdrawn quantity",
    );

    // A missed reply returns the hold; a later click cannot revive the invitation.
    await post();
    await send();
    await page
      .getByRole("button", { name: "Advance 10 minutes", exact: true })
      .click();
    await role("riverside");
    assert.match(await text(), /No boxes are reserved for you/);
    assert.equal(
      await page.getByRole("button", { name: /^Accept [0-9]+ boxes$/ }).count(),
      0,
    );
    assert.equal((await state()).requests.riverside.status, "expired");
    console.log("PASS: expired invitation cannot become a reservation");

    // Collection help must remain pending until a collector and recipient agree.
    await post();
    await send();
    await role("riverside");
    await page
      .getByRole("button", { name: "Need help collecting", exact: true })
      .click();
    assert.equal((await state()).requests.riverside.status, "help");
    await role("desk");
    await page
      .getByText("Lee, an approved volunteer, confirmed capacity", {
        exact: false,
      })
      .click();
    await page
      .getByRole("button", { name: "Record collection help", exact: true })
      .click();
    assert.equal((await state()).requests.riverside.status, "offered");
    await accept("riverside");
    assert.equal((await state()).requests.riverside.collector, "Lee");
    await role("desk");
    assert.doesNotMatch(
      await page.locator(".next-action").innerText(),
      /van is tentative/,
    );
    assert.match(
      await page.locator(".next-action").innerText(),
      /Bridge Centre/,
    );
    console.log("PASS: collection help does not silently confirm a pickup");

    // A short receipt remains visible and never becomes available food again.
    await post();
    await send();
    await accept("riverside");
    await accept("bridge");
    await collect("riverside", "314159");
    await role("riverside");
    await page
      .getByText("Report a different quantity or problem", { exact: true })
      .click();
    await page.getByLabel("Boxes actually accepted").fill("33");
    await page
      .getByLabel("What happened?", { exact: true })
      .fill("Two boxes were damaged and were not accepted.");
    await page
      .getByRole("button", { name: "Record actual receipt", exact: true })
      .click();
    assert.match(await text(), /2 need coordinator follow-up/);
    await role("desk");
    assert.match(
      await page.locator(".balances").innerText(),
      /0\s+available to offer/,
    );
    await page
      .getByText("Record the confirmed outcome", { exact: true })
      .click();
    await page
      .getByLabel("What happened to the remaining boxes?")
      .selectOption("damaged");
    await page
      .getByLabel("Who confirmed this?")
      .fill("Maya, receiving contact");
    await page
      .getByLabel("What did they confirm?")
      .fill(
        "Two damaged boxes were accounted for under the network procedure.",
      );
    await page
      .getByRole("button", { name: "Record outcome", exact: true })
      .click();
    assert.equal((await state()).requests.riverside.received, 33);
    assert.match(
      await page.locator(".balances").innerText(),
      /2\s+reported damaged/,
    );
    assert.match(await page.locator(".balances").innerText(), /33\s+received/);
    assert.match(
      await page.locator(".subticket").first().innerText(),
      /33 boxes received/,
    );
    console.log(
      "PASS: short receipt and separately attributed outcome preserve the count",
    );

    await page.screenshot({
      path: "/tmp/food-rescue-desktop.png",
      fullPage: true,
    });
    await post();
    await page.setViewportSize({ width: 390, height: 844 });
    await page.getByRole("button", { name: "Start over", exact: true }).click();
    assert.equal(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
      true,
    );
    await page.screenshot({
      path: "/tmp/food-rescue-mobile.png",
      fullPage: true,
    });
    await page
      .getByText("These are sealed meal boxes.", { exact: false })
      .click();
    await page
      .getByRole("button", { name: /^Offer [0-9]+ meal boxes$/ })
      .click();
    await send();
    await accept("riverside");
    await accept("bridge");
    await collect("riverside", "314159");
    await role("riverside");
    assert.equal(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
      true,
    );
    await page
      .getByRole("button", { name: "Received all 35 boxes", exact: true })
      .click();
    assert.match(await text(), /35 boxes received/);
    await page.screenshot({
      path: "/tmp/food-rescue-mobile-receipt.png",
      fullPage: true,
    });
    assert.deepEqual(errors, []);
    console.log(
      "PASS: narrow viewport has no horizontal overflow; no browser script errors",
    );
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
