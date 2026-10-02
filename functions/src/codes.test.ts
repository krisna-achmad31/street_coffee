import { test } from "node:test";
import assert from "node:assert/strict";
import { codeForWindow, distanceMeters, jakartaDayKey, normalize, windowFor } from "./codes";

// Same vector as test/core/redeem_code_test.dart (kRedeemVector).
test("matches the shared client test vector", () => {
  assert.equal(codeForWindow("vector-secret", "vector-promo", 58312345), "HR8J3H");
});

test("stable within a window, different across windows", () => {
  const t0 = Date.UTC(2026, 8, 28, 21, 4, 30);
  const w = windowFor(t0);
  assert.equal(windowFor(t0 + 29_000), w);
  assert.equal(windowFor(t0 + 30_000), w + 1);
  assert.notEqual(codeForWindow("s", "p", w), codeForWindow("s", "p", w + 1));
});

test("normalize", () => assert.equal(normalize(" 7f3-k9q "), "7F3K9Q"));

test("jakarta day rolls over at 17:00 UTC", () => {
  assert.equal(jakartaDayKey(Date.UTC(2026, 8, 28, 16, 59)), "20260928");
  assert.equal(jakartaDayKey(Date.UTC(2026, 8, 28, 17, 0)), "20260929");
});

test("distance", () => {
  const d = distanceMeters(-6.2441, 106.7991, -6.2450, 106.7991);
  assert.ok(d > 95 && d < 105, `got ${d}`);
});
