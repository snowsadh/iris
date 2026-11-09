import assert from "node:assert/strict";
import test from "node:test";
import {
  possibleInstants,
  readLocal,
  localValue,
  formatTime,
} from "../../src/web/time.js";

test("site-local times keep their meaning on a device in another zone", () => {
  assert.deepEqual(possibleInstants("2026-07-09T18:00", "Europe/London"), [
    "2026-07-09T17:00:00.000Z",
  ]);
  assert.deepEqual(possibleInstants("2026-11-09T18:00", "Europe/London"), [
    "2026-11-09T18:00:00.000Z",
  ]);
  assert.deepEqual(possibleInstants("2026-11-09T18:00", "Asia/Kathmandu"), [
    "2026-11-09T12:15:00.000Z",
  ]);
  assert.equal(
    localValue("2026-11-09T12:15:00Z", "Asia/Kathmandu"),
    "2026-11-09T18:00",
  );
});

test("clock-change gaps and repeated readings are explicit", () => {
  assert.deepEqual(
    possibleInstants("2026-03-08T02:30", "America/New_York"),
    [],
  );
  const repeated = possibleInstants("2026-11-01T01:30", "America/New_York");
  assert.deepEqual(repeated, [
    "2026-11-01T05:30:00.000Z",
    "2026-11-01T06:30:00.000Z",
  ]);
  const input = new FormData();
  input.set("pickup", "2026-11-01T01:30");
  assert.throws(
    () => readLocal(input, "pickup", "America/New_York"),
    /occurs twice/,
  );
  input.set("pickup_instant", repeated[1]);
  assert.equal(readLocal(input, "pickup", "America/New_York"), repeated[1]);
  input.set("pickup", "2026-03-08T02:30");
  assert.throws(
    () => readLocal(input, "pickup", "America/New_York"),
    /does not exist/,
  );
});

test("unknowns stay empty and dates cannot silently roll into another day", () => {
  assert.equal(localValue(null, "UTC"), "");
  assert.equal(localValue("", "UTC"), "");
  assert.equal(localValue("invalid", "UTC"), "");
  assert.equal(localValue("2026-11-09T18:00:00Z", undefined), "");
  assert.throws(
    () => possibleInstants("2026-02-30T18:00", "UTC"),
    /valid date/,
  );
  assert.throws(
    () => possibleInstants("2026-11-09T18:00", undefined),
    /site time zone/,
  );
  assert.match(formatTime("2026-11-09T18:00:00Z", "UTC"), /2026/);
});
