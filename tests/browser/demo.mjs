/** Check real demo identities, distinct titles and independent native logout. */
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { openDemo } from "../../scripts/open_demo.mjs";

const base = process.env.ALLFEDO_BASE_URL || "http://127.0.0.1:52773/allfedo/";
let browser;
try {
  await assert.rejects(openDemo({}, "https://example.com/allfedo/"));
  const configuration = JSON.parse(await readFile(".env.demo.json", "utf8"));
  browser = await openDemo(configuration, base, { headless: true });
  const contexts = browser.contexts();
  assert.equal(contexts.length, 6);
  const titles = await Promise.all(contexts.map(context => context.pages()[0].title()));
  assert.equal(new Set(titles).size, 6);
  for (const title of titles) assert.ok(title.endsWith(" · Allfedo"));

  const logout = await contexts[0].request.post(new URL("api/logout", base).href, {
    data: {}, headers: { "X-Allfedo-Request": "1" },
  });
  assert.ok(logout.ok());
  const other = await contexts[1].request.get(new URL("api/session", base).href);
  assert.ok(other.ok());
  assert.equal((await other.json()).user.role, "kitchen");
  console.log("Demo checks passed: six native identities, distinct titles and independent logout. No model call.");
} catch {
  // Assertion and browser errors may contain credentials. Keep diagnostics private.
  console.error("Demo checks failed. Prepare the local runtime and demo accounts, then rerun.");
  process.exitCode = 1;
} finally {
  if (browser) {
    for (const context of browser.contexts()) {
      await context.request.post(new URL("api/logout", base).href, {
        data: {}, headers: { "X-Allfedo-Request": "1" },
      }).catch(() => {});
    }
    await browser.close();
  }
}
