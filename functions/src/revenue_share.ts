import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { jakartaMonthKey } from "./codes";
import { PARTNER_SHARE, PRICE_MONTHLY, PRICE_YEARLY, REGION, STORE_FEE } from "./config";

/** Net monthly revenue one active member contributes (yearly amortised). */
export function memberMonthlyNet(plan: string): number {
  const gross = plan === "yearly" ? PRICE_YEARLY / 12 : PRICE_MONTHLY;
  return gross * (1 - STORE_FEE);
}

/** [start, end) of the previous calendar month in WIB, as UTC instants. */
export function previousJakartaMonth(nowMs: number): { start: Date; end: Date; key: string } {
  const WIB = 7 * 3600 * 1000;
  const local = new Date(nowMs + WIB);
  const y = local.getUTCFullYear();
  const m = local.getUTCMonth();
  const start = new Date(Date.UTC(y, m - 1, 1) - WIB);
  const end = new Date(Date.UTC(y, m, 1) - WIB);
  return { start, end, key: jakartaMonthKey(start.getTime()) };
}

/** Splits the pool proportionally to points, rounding down to whole rupiah. */
export function splitPool(pool: number, points: Map<string, number>): Map<string, number> {
  const total = [...points.values()].reduce((a, b) => a + b, 0);
  const out = new Map<string, number>();
  if (total === 0) return out;
  for (const [shopId, p] of points) out.set(shopId, Math.floor((pool * p) / total));
  return out;
}

/**
 * 1st of every month, 02:00 WIB: pay partner shops 20% of last month's net
 * Street Pass revenue, split by verified redemptions (PRD lubang #2).
 * Writes revenue_share/{yyyymm}/shops/{shopId}; payouts are sent manually.
 */
export const settleRevenueShare = onSchedule(
  { schedule: "0 2 1 * *", timeZone: "Asia/Jakarta", region: REGION },
  async () => {
    const db = getFirestore();
    const { start, end, key } = previousJakartaMonth(Date.now());

    const members = await db
      .collection("memberships")
      .where("activeUntil", ">=", Timestamp.fromDate(start))
      .get();
    // Active at some point during the month: ended after it started, began before it ended.
    const inMonth = members.docs.filter(
      (m) => ((m.get("since") as Timestamp | undefined)?.toMillis() ?? 0) < end.getTime());
    const net = inMonth.reduce((sum, m) => sum + memberMonthlyNet(m.get("plan")), 0);
    const pool = Math.floor(net * PARTNER_SHARE);

    const redemptions = await db
      .collection("redemptions")
      .where("createdAt", ">=", Timestamp.fromDate(start))
      .where("createdAt", "<", Timestamp.fromDate(end))
      .get();
    const points = new Map<string, number>();
    redemptions.forEach((r) => {
      const s = r.get("shopId") as string;
      points.set(s, (points.get(s) ?? 0) + 1);
    });

    const payouts = splitPool(pool, points);
    const batch = db.batch();
    batch.set(db.collection("revenue_share").doc(key), {
      pool,
      netRevenue: Math.floor(net),
      members: inMonth.length,
      redemptions: redemptions.size,
      settledAt: FieldValue.serverTimestamp(),
    });
    for (const [shopId, amount] of payouts) {
      batch.set(db.collection("revenue_share").doc(key).collection("shops").doc(shopId), {
        points: points.get(shopId),
        amount,
        pool,
        status: "pending_transfer",
      });
    }
    await batch.commit();
  },
);
