import assert from "node:assert/strict";
import test from "node:test";
import { api } from "../../src/web/api.js";

test("just-now reports use the server time once and preserve it after a lost response", async (t) => {
  const originalFetch = globalThis.fetch;
  const originalStorage = globalThis.sessionStorage;
  t.after(() => {
    globalThis.fetch = originalFetch;
    globalThis.sessionStorage = originalStorage;
  });
  const stored = new Map();
  globalThis.sessionStorage = {
    getItem: key => stored.get(key),
    setItem: (key, value) => stored.set(key, value),
    removeItem: key => stored.delete(key),
  };
  const serverTime = "2026-11-09T13:19:06.123456Z";
  const sent = [];
  let clockReads = 0;
  globalThis.fetch = async (url, options = {}) => {
    if (url.endsWith("/session")) {
      clockReads++;
      return Response.json({ ok: true, now: serverTime });
    }
    sent.push(options.body);
    if (sent.length === 1) throw new TypeError("Connection lost after save");
    return Response.json({ ok: true });
  };
  api.setActor("transport-test");
  let uncertain;
  try {
    await api.command("handoff", { allocation_id: "1", occurred_at: null });
    assert.fail("The lost response must require recovery.");
  } catch (error) {
    assert.ok(error.command);
    uncertain = error;
  }
  assert.equal(JSON.parse(sent[0]).payload.occurred_at, serverTime);
  // Reloaded UI restores the same request instead of dating the report again.
  api.setActor("transport-test");
  await api.retry(uncertain);
  assert.equal(sent[1], sent[0]);
  assert.equal(clockReads, 1);
  assert.equal(api.pending().length, 0);

  const earlier = "2026-11-09T12:00:00.987654Z";
  await api.command("handoff", { allocation_id: "2", occurred_at: earlier });
  assert.equal(JSON.parse(sent[2]).payload.occurred_at, earlier);
  assert.equal(clockReads, 1, "An explicitly dated report must keep its stated time.");
});
