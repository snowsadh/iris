/** Local demonstration helper. Each account uses native sign-in and a separate cookie store. */
import { readFile } from "node:fs/promises";
import { once } from "node:events";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const profiles = {
  coordinator: "coordinator",
  northside: "kitchen",
  riverside: "recipient",
  collector: "collector",
  bridge: "recipient",
  harbor: "kitchen",
};

export async function openDemo(configuration, address, { headless = false } = {}) {
  const base = new URL(address);
  if (base.protocol !== "http:" || base.hostname !== "127.0.0.1" || base.pathname !== "/allfedo/")
    throw new Error("Use the local Allfedo address printed by demo setup.");
  const browser = await chromium.launch({
    headless,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE
      ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE }
      : {}),
  });
  try {
    const identities = new Set();
    for (const [profile, role] of Object.entries(profiles)) {
      const account = configuration.accounts[profile];
      const context = await browser.newContext({ viewport: { width: 1360, height: 900 } });
      const page = await context.newPage();
      await page.goto(base.href);
      if (new URL(page.url()).origin !== base.origin)
        throw new Error("The sign-in page changed origin.");
      const action = await page.locator('form:has(input[name="IRISPassword"])').getAttribute("action");
      if (new URL(action || page.url(), page.url()).origin !== base.origin)
        throw new Error("The sign-in form changed origin.");
      await page.locator('[name="IRISUsername"]').fill(account.username);
      await page.locator('[name="IRISPassword"]').fill(account.password);
      await page.locator('[name="IRISLogin"]').click();
      await page.locator('#screen:not([aria-busy]) h1').waitFor();
      const response = await context.request.get(new URL("api/session", base).href);
      const session = await response.json();
      if (!response.ok() || session.user?.role !== role || session.user?.network_id !== configuration.network_id || session.user?.demo !== true || identities.has(session.user.id))
        throw new Error("A demonstration session did not match its invited identity.");
      identities.add(session.user.id);
      if (await page.getByRole("heading", { name: "This page could not be opened", exact: true }).count())
        throw new Error("The demonstration page could not read its records.");
    }
    return browser;
  } catch {
    await browser.close();
    // Browser diagnostics can include filled form values. Never print the underlying exception.
    throw new Error("A demo window could not open. Check the local runtime and rerun demo setup.");
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    const configuration = JSON.parse(await readFile(process.argv[2], "utf8"));
    const browser = await openDemo(configuration, process.argv[3]);
    console.log("Opened six independent partner sessions. Close their windows when finished. No model call was made.");
    await once(browser, "disconnected");
  } catch {
    console.error("Demo browser could not open. Check setup and install the browser tools: npm ci; npx playwright install chromium.");
    process.exitCode = 1;
  }
}
