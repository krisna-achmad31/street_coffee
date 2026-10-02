import { randomBytes } from "node:crypto";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { google } from "googleapis";
import { ANDROID_PACKAGE, REGION } from "./config";

const PLANS: Record<string, "monthly" | "yearly"> = {
  street_pass_monthly: "monthly",
  street_pass_yearly: "yearly",
};

/**
 * The only place a Street Pass membership is granted. The app sends the
 * store token; we ask Google Play for the real expiry before writing.
 * The function's service account needs "View financial data" in Play Console.
 */
export const verifyPassPurchase = onCall({ region: REGION }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Masuk dulu.");
  const { platform, productId, token } = req.data ?? {};
  const plan = PLANS[productId as string];
  if (!plan || typeof token !== "string") {
    throw new HttpsError("invalid-argument", "Produk tidak dikenal.");
  }
  if (platform !== "android") {
    // App Store Server API verification is not wired up yet.
    throw new HttpsError("unimplemented", "Pembelian iOS belum didukung.");
  }

  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const publisher = google.androidpublisher({ version: "v3", auth });
  const res = await publisher.purchases.subscriptionsv2.get({
    packageName: ANDROID_PACKAGE.value(),
    token,
  });
  const sub = res.data;
  const expiry = sub.lineItems?.[0]?.expiryTime;
  const state = sub.subscriptionState;
  const ok =
    expiry &&
    (state === "SUBSCRIPTION_STATE_ACTIVE" || state === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD");
  if (!ok) throw new HttpsError("failed-precondition", `Langganan tidak aktif (${state}).`);

  // One token can only ever belong to one account.
  const db = getFirestore();
  const tokenRef = db.collection("purchase_tokens").doc(token.slice(0, 1400));
  const until = Timestamp.fromDate(new Date(expiry));
  await db.runTransaction(async (tx) => {
    const owner = await tx.get(tokenRef);
    if (owner.exists && owner.get("uid") !== uid) {
      throw new HttpsError("already-exists", "Pembelian ini terdaftar di akun lain.");
    }
    const memberRef = db.collection("memberships").doc(uid);
    const member = await tx.get(memberRef);
    tx.set(tokenRef, { uid, productId, updatedAt: FieldValue.serverTimestamp() });
    tx.set(memberRef, {
      plan,
      platform,
      activeUntil: until,
      redeemSecret: member.get("redeemSecret") ?? randomBytes(32).toString("hex"),
      updatedAt: FieldValue.serverTimestamp(),
      ...(member.exists ? {} : { since: FieldValue.serverTimestamp() }),
    }, { merge: true });
    tx.set(db.collection("users").doc(uid), { passUntil: until }, { merge: true });
  });
  return { active: true, activeUntil: until.toMillis() };
});
