import { getFirestore, FieldPath, FieldValue, Timestamp } from "firebase-admin/firestore";
import { onDocumentCreated, onDocumentDeleted, onDocumentWritten } from "firebase-functions/v2/firestore";
import { CHECKIN_RADIUS_METERS, REGION } from "./config";
import { distanceMeters, jakartaDayKey, jakartaHourField, jakartaMonthKey } from "./codes";

const db = () => getFirestore();

/**
 * New Drop: verify GPS against the shop, award the passport stamp,
 * count Regulars (max 1 check-in per day), fan out to followers.
 */
export const onDropCreated = onDocumentCreated(
  { document: "drops/{dropId}", region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const drop = snap.data();
    const uid = drop.userId as string;
    const shopId = drop.shopId as string;
    const shop = await db().collection("coffee_shops").doc(shopId).get();
    if (!shop.exists) {
      await snap.ref.update({ verified: false, hidden: true });
      return;
    }

    const meters = distanceMeters(
      drop.latitude, drop.longitude, shop.get("latitude"), shop.get("longitude"));
    const verified = meters <= CHECKIN_RADIUS_METERS;
    const now = Date.now();
    const day = jakartaDayKey(now);

    const userRef = db().collection("users").doc(uid);
    const stampRef = userRef.collection("stamps").doc(shopId);
    const regularRef = db()
      .collection("coffee_shops").doc(shopId)
      .collection(`regulars_${jakartaMonthKey(now)}`).doc(uid);

    const earlier = await db()
      .collection("drops")
      .where("shopId", "==", shopId)
      .where("createdAt", "<", drop.createdAt as Timestamp)
      .limit(1)
      .get();

    const followers = await userRef.collection("followers").limit(500).get();

    await db().runTransaction(async (tx) => {
      const [user, stamp, regular] = await Promise.all([
        tx.get(userRef), tx.get(stampRef), tx.get(regularRef),
      ]);
      let stampNumber = 0;
      if (verified) {
        if (stamp.exists) {
          stampNumber = stamp.get("number") ?? 0;
        } else {
          stampNumber = ((user.get("stampsCount") as number | undefined) ?? 0) + 1;
          tx.set(stampRef, {
            number: stampNumber,
            shopName: shop.get("name"),
            imageUrl: shop.get("imageUrl") ?? "",
            area: shop.get("area") ?? null,
            firstVisit: FieldValue.serverTimestamp(),
          });
          tx.set(userRef, { stampsCount: FieldValue.increment(1) }, { merge: true });
        }
        if (regular.get("lastDay") !== day) {
          tx.set(regularRef, {
            handle: drop.userHandle,
            photoUrl: drop.userPhotoUrl ?? null,
            checkins: FieldValue.increment(1),
            lastDay: day,
          }, { merge: true });
        }
      }
      tx.set(userRef, { dropsCount: FieldValue.increment(1) }, { merge: true });
      const statRef = db().collection("coffee_shops").doc(shopId).collection("stats").doc(day);
      tx.set(statRef, {
        day,
        drops: FieldValue.increment(1),
        [jakartaHourField(now)]: FieldValue.increment(1),
      }, { merge: true });
      const menu = typeof drop.menuItem === "string" ? drop.menuItem.trim().slice(0, 60) : "";
      if (menu) {
        // FieldPath keeps menu names with dots or spaces as a single map key.
        tx.update(statRef, new FieldPath("menu", menu), FieldValue.increment(1));
      }
      tx.update(snap.ref, {
        verified,
        distanceMeters: Math.round(meters),
        stampNumber,
        isFirstAtShop: verified && earlier.empty,
        followerIds: followers.docs.map((d) => d.id),
      });
    });
  },
);

/** Cheers counter + notification to the author. */
export const onCheersWritten = onDocumentWritten(
  { document: "drops/{dropId}/cheers/{uid}", region: REGION },
  async (event) => {
    const before = event.data?.before.exists ?? false;
    const after = event.data?.after.exists ?? false;
    if (before === after) return;
    const dropRef = db().collection("drops").doc(event.params.dropId);
    await dropRef.update({ cheersCount: FieldValue.increment(after ? 1 : -1) });
    if (!after) return;
    const drop = await dropRef.get();
    const author = drop.get("userId") as string;
    if (!author || author === event.params.uid) return;
    const actor = await db().collection("users").doc(event.params.uid).get();
    await notify(author, {
      kind: "cheers",
      text: `${actor.get("handle") ?? "Seseorang"} kasih ☕ Cheers ke Drop kamu di ${drop.get("shopName")}`,
      actorPhotoUrl: actor.get("photoUrl") ?? null,
      thumbUrl: (drop.get("photoUrls") ?? [])[0] ?? null,
      targetId: drop.id,
    });
  },
);

export const onDropCommentCreated = onDocumentCreated(
  { document: "drops/{dropId}/comments/{commentId}", region: REGION },
  async (event) => {
    const c = event.data?.data();
    if (!c) return;
    const dropRef = db().collection("drops").doc(event.params.dropId);
    await dropRef.update({ commentCount: FieldValue.increment(1) });
    const drop = await dropRef.get();
    const author = drop.get("userId") as string;
    if (!author || author === c.userId) return;
    await notify(author, {
      kind: "comment",
      text: `${c.userName} mengomentari: "${String(c.text).slice(0, 80)}"`,
      actorPhotoUrl: c.userPhotoUrl ?? null,
      thumbUrl: (drop.get("photoUrls") ?? [])[0] ?? null,
      targetId: drop.id,
    });
  },
);

export const onDropCommentDeleted = onDocumentDeleted(
  { document: "drops/{dropId}/comments/{commentId}", region: REGION },
  async (event) => {
    await db().collection("drops").doc(event.params.dropId)
      .update({ commentCount: FieldValue.increment(-1) });
  },
);

/** Keeps coffee_shops.isPartner in sync with active member-only promos. */
export const onPromoWritten = onDocumentWritten(
  { document: "promos/{promoId}", region: REGION },
  async (event) => {
    const shopId = (event.data?.after.get("shopId") ?? event.data?.before.get("shopId")) as string;
    if (!shopId) return;
    const active = await db()
      .collection("promos")
      .where("shopId", "==", shopId)
      .where("memberOnly", "==", true)
      .where("endAt", ">", Timestamp.now())
      .limit(1)
      .get();
    await db().collection("coffee_shops").doc(shopId).update({ isPartner: !active.empty });
  },
);

async function notify(uid: string, n: Record<string, unknown>) {
  await db().collection("users").doc(uid).collection("notifications").add({
    ...n,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}
