/** Paid, opt-in check. Never include this file in ordinary browser checks. */
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { chromium } from "playwright";

let browser, page, logoutURL;
let step = "Read the private test fixture and local key";
try {
  const fixture = JSON.parse(await readFile(process.env.ALLFEDO_BROWSER_ACCOUNTS, "utf8"));
  const settings = Object.fromEntries((await readFile(".env", "utf8")).split(/\r?\n/).filter(line => /^[A-Z_]+=/.test(line)).map(line => {
    const split = line.indexOf("=");
    let value = line.slice(split + 1).trim();
    if (value.startsWith("'") && value.endsWith("'")) value = value.slice(1, -1).replaceAll("\\'", "'");
    else if (value.startsWith('"') && value.endsWith('"')) value = JSON.parse(value);
    return [line.slice(0, split), value];
  }));
  const key = process.env.AI_API_KEY || settings.AI_API_KEY || process.env.OPENAI_API_KEY || settings.OPENAI_API_KEY;
  assert.ok(key);
  const base = new URL(fixture.base_url);
  assert.equal(base.hostname, "127.0.0.1");
  logoutURL = new URL("api/logout", base).href;
  browser = await chromium.launch({ headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {}),
  });
  page = await browser.newPage();
  await page.goto(base.href);
  assert.equal(new URL(page.url()).origin, base.origin);
  const form = page.locator('form:has(input[name="IRISPassword"])');
  assert.equal(new URL(await form.getAttribute("action") || page.url(), page.url()).origin, base.origin);
  await page.locator('[name="IRISUsername"]').fill(fixture.accounts.coordinator.username);
  await page.locator('[name="IRISPassword"]').fill(fixture.accounts.coordinator.password);
  await page.locator('[name="IRISLogin"]').click();
  await page.locator('#screen:not([aria-busy]) h1').waitFor();
  const get = async path => {
    const response = await page.request.get(new URL(`api/${path}`, base).href);
    assert.ok(response.ok());
    return response.json();
  };
  const defaults = (await get("ai-settings")).default;
  assert.equal(defaults.available, true);
  const offer = (await get("offers")).records.find(record => record.state === "open" && Number(record.available_quantity) > 0);
  assert.ok(offer);
  const heldBefore = offer.held_quantity;
  step = "Save the local key through the personal Settings form";
  await page.goto(new URL("#/settings", base).href);
  await page.getByText("Use my own API key", { exact: true }).click();
  await page.locator("#ai-provider").selectOption(defaults.provider);
  await page.locator("#ai-model").fill(defaults.model);
  await page.locator("#ai-key").fill(key);
  await page.getByRole("button", { name: "Use my key", exact: true }).click();
  await page.getByRole("heading", { name: "Using your key", exact: true }).waitFor();
  const results = [];
  for (const source of ["personal", "default"]) {
    step = `Request a live native plan using the ${source} connection`;
    if (source === "default") {
      const response = await page.request.post(new URL("api/ai-settings", base).href, { data: {}, headers: { "X-Allfedo-Request": "1" } });
      assert.ok(response.ok());
    }
    await page.goto(new URL(`#/offers/${offer.id}/plan`, base).href);
    await page.locator('#screen:not([aria-busy]) h1').waitFor();
    const pending = page.waitForResponse(response => response.url().endsWith("/api/commands") && response.request().method() === "POST", { timeout: 110000 });
    await page.getByRole("button", { name: "Get a planning suggestion", exact: true }).click();
    const response = await pending;
    assert.equal(response.request().postData().includes(key), false);
    assert.ok(response.ok());
    const outcome = await response.json();
    assert.equal(outcome.ok, true);
    assert.equal(outcome.state, "proposed");
    const saved = (await get(`plans/${offer.id}`)).record;
    assert.equal(saved.run_id, outcome.run_id);
    assert.equal(saved.provider, defaults.provider);
    assert.equal(saved.credential_source, source);
    assert.ok(saved.tool_audit.some(entry => entry.tool === "SubmitProposal"));
    assert.equal(JSON.stringify(saved).includes(key), false);
    assert.equal((await get(`offers/${offer.id}`)).record.held_quantity, heldBefore);
    results.push({ source, provider: saved.provider, model: saved.model, run_id: saved.run_id });
  }
  console.log(JSON.stringify({ passed: true, paid_planning_attempts: 2, saved_results: results, reservation_created: false }));
} catch {
  // Credentials and provider responses stay out of diagnostics and screenshots.
  console.error(`Live planning check failed at: ${step}. Inspect the saved run; do not retry blindly.`);
  process.exitCode = 1;
} finally {
  if (page) await page.request.post(logoutURL,
    { data: {}, headers: { "X-Allfedo-Request": "1" } }).catch(() => {});
  if (browser) await browser.close();
}
