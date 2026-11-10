/** Real native sessions and wallet settings. Uses a fake key and makes no model call. */
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { request } from "playwright";
import { openDemo } from "../../scripts/open_demo.mjs";

const base = process.env.ALLFEDO_BASE_URL || "http://127.0.0.1:52773/allfedo/";
const headers = { "X-Allfedo-Request": "1" };
const fakeKey = "allfedo-settings-test-not-a-real-key";
let browser, secondSession;
let step = "Open the six native demo sessions";
try {
  const configuration = JSON.parse(await readFile(".env.demo.json", "utf8"));
  browser = await openDemo(configuration, base, { headless: true });
  const [coordinator, kitchen] = browser.contexts();
  const page = coordinator.pages()[0];
  const endpoint = new URL("api/ai-settings", base).href;
  const account = configuration.accounts.coordinator;
  secondSession = await request.newContext({
    extraHTTPHeaders: { Authorization: `Basic ${Buffer.from(`${account.username}:${account.password}`).toString("base64")}` },
  });

  step = "Default settings and denied partner access";
  assert.equal((await coordinator.request.get(endpoint)).status(), 200);
  assert.equal((await kitchen.request.get(endpoint)).status(), 403);
  assert.equal((await kitchen.request.post(endpoint, { data: {}, headers })).status(), 403);
  const bad = await coordinator.request.post(endpoint, { data: { provider: "unknown", model: "none", api_key: fakeKey }, headers });
  assert.equal(bad.status(), 422);

  step = "Save a personal key through the actual Settings form";
  await page.goto(new URL("#/settings", base).href);
  await page.getByRole("heading", { name: "Planning AI", exact: true }).waitFor();
  await page.getByText("Use my own API key", { exact: true }).click();
  await page.locator("#ai-provider").selectOption("openrouter");
  assert.equal(await page.locator("#ai-model").inputValue(), "openai/gpt-4.1-mini");
  await page.locator("#ai-key").fill(fakeKey);
  await page.getByRole("button", { name: "Use my key", exact: true }).click();
  await page.getByRole("heading", { name: "Using your key", exact: true }).waitFor();
  const personal = await (await coordinator.request.get(endpoint)).json();
  assert.equal(personal.source, "personal");
  assert.equal(personal.personal.provider, "openrouter");
  assert.equal(JSON.stringify(personal).includes(fakeKey), false);
  assert.equal(await page.locator("#ai-key").inputValue(), "");
  assert.equal(await page.evaluate(key => JSON.stringify({ ...localStorage, ...sessionStorage }).includes(key), fakeKey), false);

  step = "Another session of the same account keeps its own default connection";
  const isolated = await secondSession.get(endpoint);
  assert.equal(isolated.status(), 200);
  assert.equal((await isolated.json()).source, "default");

  step = "Narrow layouts keep the settings usable";
  for (const width of [1440, 900, 390, 320]) {
    await page.setViewportSize({ width, height: 900 });
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
  }

  step = "Remove the personal connection and retain only default settings";
  const remove = page.getByRole("button", { name: /^(Use default AI|Remove my key)$/ });
  await remove.click();
  await page.getByRole("heading", { name: "Default connection", exact: true }).waitFor();
  assert.equal((await (await coordinator.request.get(endpoint)).json()).source, "default");

  step = "Sign-out removes a newly saved personal connection";
  const saved = await coordinator.request.post(endpoint, { data: { provider: "openai", model: "gpt-4.1-mini", api_key: fakeKey }, headers });
  assert.equal(saved.status(), 200);
  assert.equal((await saved.json()).source, "personal");
  const logout = await coordinator.request.post(new URL("api/logout", base).href, { data: {}, headers });
  assert.ok(logout.ok());
  console.log("Settings checks passed: real wallet save, no key echo or browser storage, session isolation, role checks, model selection, removal, logout and responsive layouts. No model call.");
} catch {
  // Browser and HTTP diagnostics can contain login headers. Never print raw errors.
  console.error(`Settings checks failed at: ${step}.`);
  process.exitCode = 1;
} finally {
  if (secondSession) {
    await secondSession.post(new URL("api/logout", base).href, { data: {}, headers }).catch(() => {});
    await secondSession.dispose();
  }
  if (browser) {
    for (const context of browser.contexts())
      await context.request.post(new URL("api/logout", base).href, { data: {}, headers }).catch(() => {});
    await browser.close();
  }
}
