import { defineString } from "firebase-functions/params";

/** Jakarta — closest region to users and shops. Keep in sync with the app. */
export const REGION = "asia-southeast2";

/** Comma-separated admin uids (same person as AdminConfig.adminUid). */
export const ADMIN_UIDS = defineString("ADMIN_UIDS", { default: "" });

/** Android application id used for Play purchase verification. */
export const ANDROID_PACKAGE = defineString("ANDROID_PACKAGE", {
  default: "com.streetcoffee.app.street_coffees",
});

/** List prices (rupiah) used to size the revenue-share pool. */
export const PRICE_MONTHLY = 19000;
export const PRICE_YEARLY = 149000;

/** Store fee for subscriptions (Play / App Store small-business rate). */
export const STORE_FEE = 0.15;

/** Share of net Street Pass revenue paid out to partner shops. */
export const PARTNER_SHARE = 0.2;

/** A Drop earns a stamp only when posted within this radius of the shop. */
export const CHECKIN_RADIUS_METERS = 150;

export function isAdminUid(uid: string): boolean {
  return ADMIN_UIDS.value()
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
    .includes(uid);
}
