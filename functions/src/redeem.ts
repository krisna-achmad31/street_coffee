import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { codeForWindow, jakartaDayKey, jakartaHourField, normalize, windowFor, CODE_LENGTH } from "./codes";
import { REGION, isAdminUid } from "./config";

type Reason = "ok" | "expired" | "used_today" | "quota_empty" | "not_member" | "not_found";

/**
 * Cashier validates a member's rotating code (PRD lubang #1).
 *
 * Codes are tied to a member secret, so the server narrows the search to
 * members who opened "Pakai Promo" at this shop in the last 2 minutes
 * (redeem_intents) instead of scanning every member.
 */
export const redeemPromo = onCall({ region: REGION }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Masuk dulu.");
  const shopId = String(req.data?.shopId ?? "");
  const code = normalize(String(req.data?.code ?? ""));
  if (!shopId || code.length !== CODE_LENGTH) {
    throw new HttpsError("invalid-argument", "Kode harus 6 karakter.");
  }

  const db = getFirestore();
  const shop = await db.collection("coffee_shops").doc(shopId).get();
  if (!shop.exists) throw new HttpsError("not-found", "Kedai tidak ditemukan.");
  const staff: string[] = shop.get("staffUids") ?? [];
  if (shop.get("ownerUid") !== uid && !staff.includes(uid) && !isAdminUid(uid)) {
    throw new HttpsError("permission-denied", "Hanya staf kedai yang bisa memvalidasi.");
  }

  const now = Date.now();
  const w = windowFor(now);
  const intents = await db
    .collection("redeem_intents")
    .where("shopId", "==", shopId)
    .where("createdAt", ">=", Timestamp.fromMillis(now - 120_000))
    .get();

  // Unique (member, promo) pairs currently at the counter.
  const pairs = new Map<string, { memberUid: string; promoId: string }>();
  intents.forEach((d) => {
    const memberUid = d.get("uid") as string;
    const promoId = d.get("promoId") as string;
    pairs.set(`${memberUid}|${promoId}`, { memberUid, promoId });
  });

  let match: { memberUid: string; promoId: string } | null = null;
  let expired = false;
  for (const p of pairs.values()) {
    const m = await db.collection("memberships").doc(p.memberUid).get();
    const secret = m.get("redeemSecret") as string | undefined;
    if (!secret) continue;
    // Current window + one back for clock drift.
    if ([w, w - 1].some((x) => codeForWindow(secret, p.promoId, x) === code)) {
      match = p;
      break;
    }
    // Older windows (up to 2 min) = a stale code or a screenshot.
    if ([w - 2, w - 3, w - 4].some((x) => codeForWindow(secret, p.promoId, x) === code)) {
      expired = true;
    }
  }
  if (!match) return { valid: false, reason: (expired ? "expired" : "not_found") as Reason };

  const { memberUid, promoId } = match;
  const day = jakartaDayKey(now);
  const promoRef = db.collection("promos").doc(promoId);
  const redemptionRef = db.collection("redemptions").doc(`${promoId}_${memberUid}_${day}`);
  const memberRef = db.collection("memberships").doc(memberUid);
  const userRef = db.collection("users").doc(memberUid);

  return db.runTransaction(async (tx) => {
    const [promo, prior, membership, user] = await Promise.all([
      tx.get(promoRef),
      tx.get(redemptionRef),
      tx.get(memberRef),
      tx.get(userRef),
    ]);
    if (!promo.exists || promo.get("shopId") !== shopId) {
      return { valid: false, reason: "not_found" as Reason };
    }
    const start = (promo.get("startAt") as Timestamp).toMillis();
    const end = (promo.get("endAt") as Timestamp).toMillis();
    if (now < start || now >= end) return { valid: false, reason: "expired" as Reason };

    const activeUntil = (membership.get("activeUntil") as Timestamp | undefined)?.toMillis() ?? 0;
    if (promo.get("memberOnly") && activeUntil < now) {
      return { valid: false, reason: "not_member" as Reason };
    }
    if (prior.exists) return { valid: false, reason: "used_today" as Reason };

    const quota = promo.get("dailyQuota") as number;
    const used = (promo.get(`usage.${day}`) as number | undefined) ?? 0;
    if (used >= quota) return { valid: false, reason: "quota_empty" as Reason };

    const memberName = (user.get("displayName") as string | undefined) ?? "Member";
    tx.set(redemptionRef, {
      shopId,
      promoId,
      uid: memberUid,
      memberName,
      cashierUid: uid,
      day,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(promoRef, { [`usage.${day}`]: FieldValue.increment(1) });
    tx.set(db.collection("coffee_shops").doc(shopId).collection("stats").doc(day), {
      day,
      redemptions: FieldValue.increment(1),
      [jakartaHourField(now)]: FieldValue.increment(1),
    }, { merge: true });

    return {
      valid: true,
      reason: "ok" as Reason,
      promoTitle: promo.get("title"),
      memberName: shortName(memberName),
      redeemNumberToday: used + 1,
      quotaLeft: quota - used - 1,
      dailyQuota: quota,
    };
  });
});

/** "Nadia Rinjani" → "Nadia R." — the cashier needs no more than that. */
function shortName(full: string): string {
  const parts = full.trim().split(/\s+/);
  return parts.length > 1 ? `${parts[0]} ${parts[parts.length - 1][0]}.` : parts[0];
}
