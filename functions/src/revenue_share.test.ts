import { test } from "node:test";
import assert from "node:assert/strict";
import { memberMonthlyNet, previousJakartaMonth, splitPool } from "./revenue_share";

test("previous month boundaries follow WIB", () => {
  // 1 Oct 2026 02:00 WIB = 30 Sep 19:00 UTC → settles September.
  const r = previousJakartaMonth(Date.UTC(2026, 8, 30, 19, 0));
  assert.equal(r.key, "202609");
  assert.equal(r.start.toISOString(), "2026-08-31T17:00:00.000Z");
  assert.equal(r.end.toISOString(), "2026-09-30T17:00:00.000Z");
});

test("january settles december of the previous year", () => {
  assert.equal(previousJakartaMonth(Date.UTC(2026, 11, 31, 19, 0)).key, "202612");
  assert.equal(previousJakartaMonth(Date.UTC(2027, 0, 15)).key, "202612");
});

test("member net revenue amortises yearly plans", () => {
  assert.equal(memberMonthlyNet("monthly"), 19000 * 0.85);
  assert.equal(Math.round(memberMonthlyNet("yearly")), Math.round((149000 / 12) * 0.85));
});

test("pool split is proportional and never exceeds the pool", () => {
  const out = splitPool(2_000_000, new Map([["a", 300], ["b", 1200]]));
  assert.equal(out.get("a"), 400_000);
  assert.equal(out.get("b"), 1_600_000);
  const odd = splitPool(100, new Map([["a", 1], ["b", 1], ["c", 1]]));
  assert.ok([...odd.values()].reduce((x, y) => x + y, 0) <= 100);
  assert.equal(splitPool(100, new Map()).size, 0);
});
