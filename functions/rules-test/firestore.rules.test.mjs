// Security rules tests — run with:
//   firebase emulators:exec --only firestore "node --test functions/rules-test/"
import { test, before, after, beforeEach } from "node:test";
import { readFileSync } from "node:fs";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, addDoc,
  Timestamp, increment, serverTimestamp,
} from "firebase/firestore";

const ADMIN = "uSR6zFYKnSOMzlTYLNURchYQTw43";
const OWNER = "owner-1";
const ALICE = "alice";
const BOB = "bob";
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "street-coffee-rules",
    firestore: { rules: readFileSync(new URL("../../firestore.rules", import.meta.url), "utf8") },
  });
});
after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "coffee_shops/s1"), {
      name: "Kopi Senja", ownerUid: OWNER, isPartner: false, rating: 4.5,
      description: "x", latitude: -6.24, longitude: 106.79,
    });
    await setDoc(doc(db, "drops/published"), {
      userId: BOB, hidden: false, publishAt: Timestamp.fromMillis(Date.now() - 3600_000),
    });
    await setDoc(doc(db, "drops/delayed"), {
      userId: BOB, hidden: false, publishAt: Timestamp.fromMillis(Date.now() + 3600_000),
    });
    await setDoc(doc(db, "memberships/alice"), { redeemSecret: "s", activeUntil: Timestamp.now() });
  });
});

const as = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();

// ── Shops ──
test("anyone reads shops; only admin creates", async () => {
  await assertSucceeds(getDoc(doc(as(null), "coffee_shops/s1")));
  await assertFails(setDoc(doc(as(ALICE), "coffee_shops/new"), { name: "x" }));
  await assertSucceeds(setDoc(doc(as(ADMIN), "coffee_shops/new"), { name: "x" }));
});

test("owner edits listing but cannot change ownership or partner flag", async () => {
  await assertSucceeds(updateDoc(doc(as(OWNER), "coffee_shops/s1"), { description: "baru" }));
  await assertFails(updateDoc(doc(as(OWNER), "coffee_shops/s1"), { ownerUid: ALICE }));
  await assertFails(updateDoc(doc(as(OWNER), "coffee_shops/s1"), { isPartner: true }));
  await assertFails(updateDoc(doc(as(OWNER), "coffee_shops/s1"), { rating: 5 }));
  await assertFails(updateDoc(doc(as(ALICE), "coffee_shops/s1"), { description: "hack" }));
});

// ── Drops & "tunda lokasi" ──
test("delayed drops are hidden from others until publishAt", async () => {
  await assertSucceeds(getDoc(doc(as(ALICE), "drops/published")));
  await assertFails(getDoc(doc(as(ALICE), "drops/delayed")));
  await assertSucceeds(getDoc(doc(as(BOB), "drops/delayed")));
});

const newDrop = (uid, extra = {}) => ({
  userId: uid, cheersCount: 0, commentCount: 0, stampNumber: 0, hidden: false,
  caption: "enak", rating: 4, publishAt: Timestamp.now(), ...extra,
});

test("drops must be posted as yourself with zeroed counters", async () => {
  await assertSucceeds(setDoc(doc(as(ALICE), "drops/a1"), newDrop(ALICE)));
  await assertFails(setDoc(doc(as(ALICE), "drops/a2"), newDrop(BOB)));
  await assertFails(setDoc(doc(as(ALICE), "drops/a3"), newDrop(ALICE, { cheersCount: 999 })));
  await assertFails(setDoc(doc(as(ALICE), "drops/a4"), newDrop(ALICE, { stampNumber: 40 })));
  await assertFails(setDoc(doc(as(ALICE), "drops/a5"), newDrop(ALICE, { rating: 9 })));
  await assertFails(updateDoc(doc(as(BOB), "drops/published"), { cheersCount: 1000 }));
});

test("cheers only as yourself", async () => {
  await assertSucceeds(setDoc(doc(as(ALICE), "drops/published/cheers/alice"), { createdAt: serverTimestamp() }));
  await assertFails(setDoc(doc(as(ALICE), "drops/published/cheers/bob"), { createdAt: serverTimestamp() }));
});

// ── Attribution leads (lubang #3) ──
test("guests log leads; only the owner reads and converts them", async () => {
  const lead = { code: "SC-7F3K", uid: null, visitorId: "v", day: "20260928", converted: false };
  await assertSucceeds(setDoc(doc(as(null), "coffee_shops/s1/leads/SC-7F3K"), lead));
  await assertFails(setDoc(doc(as(null), "coffee_shops/s1/leads/SC-AAAA"), { ...lead, code: "SC-AAAA", converted: true }));
  await assertFails(getDoc(doc(as(ALICE), "coffee_shops/s1/leads/SC-7F3K")));
  await assertFails(updateDoc(doc(as(ALICE), "coffee_shops/s1/leads/SC-7F3K"), { converted: true }));
  await assertSucceeds(updateDoc(doc(as(OWNER), "coffee_shops/s1/leads/SC-7F3K"), { converted: true, convertedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(as(OWNER), "coffee_shops/s1/leads/SC-7F3K"), { converted: false }));
});

test("anyone bumps views; nobody fakes redemptions", async () => {
  await assertSucceeds(setDoc(doc(as(null), "coffee_shops/s1/stats/20260928"), { day: "20260928", views: increment(1) }, { merge: true }));
  await assertFails(setDoc(doc(as(OWNER), "coffee_shops/s1/stats/20260929"), { day: "20260929", redemptions: 50 }));
  await assertFails(updateDoc(doc(as(OWNER), "coffee_shops/s1/stats/20260928"), { redemptions: 50 }));
  await assertFails(getDoc(doc(as(ALICE), "coffee_shops/s1/stats/20260928")));
  await assertSucceeds(getDoc(doc(as(OWNER), "coffee_shops/s1/stats/20260928")));
});

// ── Promos (lubang #2) ──
const promo = (extra = {}) => ({
  shopId: "s1", type: "bundling", fundedBy: "shop", usage: {}, dailyQuota: 50,
  memberOnly: true, normalPrice: 36000, promoPrice: 30000, ...extra,
});

test("only the owner creates promos, always shop-funded and cheaper", async () => {
  await assertSucceeds(addDoc(collection(as(OWNER), "promos"), promo()));
  await assertFails(addDoc(collection(as(ALICE), "promos"), promo()));
  await assertFails(addDoc(collection(as(OWNER), "promos"), promo({ fundedBy: "platform" })));
  await assertFails(addDoc(collection(as(OWNER), "promos"), promo({ promoPrice: 40000 })));
  await assertFails(addDoc(collection(as(OWNER), "promos"), promo({ usage: { "20260928": 0 } })));
  await assertSucceeds(addDoc(collection(as(OWNER), "promos"), promo({ type: "freeItem", promoPrice: 0 })));
});

// ── Membership & profile ──
test("memberships are private and server-written", async () => {
  await assertSucceeds(getDoc(doc(as(ALICE), "memberships/alice")));
  await assertFails(getDoc(doc(as(BOB), "memberships/alice")));
  await assertFails(setDoc(doc(as(BOB), "memberships/bob"), { activeUntil: Timestamp.now() }));
});

test("users cannot grant themselves Street Pass or stamps", async () => {
  const base = { handle: "a", displayName: "A", dropsCount: 0, stampsCount: 0 };
  await assertSucceeds(setDoc(doc(as(ALICE), "users/alice"), base));
  await assertFails(setDoc(doc(as(BOB), "users/bob"), { ...base, passUntil: Timestamp.now() }));
  await assertFails(updateDoc(doc(as(ALICE), "users/alice"), { stampsCount: 40 }));
  await assertSucceeds(updateDoc(doc(as(ALICE), "users/alice"), { bio: "ngopi" }));
  await assertFails(setDoc(doc(as(ALICE), "users/alice/stamps/s1"), { number: 1 }));
});

test("redeem intents only for yourself; reports only as yourself", async () => {
  await assertSucceeds(addDoc(collection(as(ALICE), "redeem_intents"), { uid: ALICE, promoId: "p", shopId: "s1" }));
  await assertFails(addDoc(collection(as(ALICE), "redeem_intents"), { uid: BOB, promoId: "p", shopId: "s1" }));
  await assertSucceeds(addDoc(collection(as(ALICE), "reports"), { reporterUid: ALICE, status: "open" }));
  await assertFails(addDoc(collection(as(ALICE), "reports"), { reporterUid: BOB, status: "open" }));
});

// ── The app's real list queries must be allowed ──
import { query, where, orderBy, limit, getDocs } from "firebase/firestore";

const published = (db) => query(collection(db, "drops"),
  where("hidden", "==", false),
  where("publishAt", "<=", Timestamp.fromMillis(Date.now() - 60_000)));

test("feed, shop drops and own drops queries are allowed", async () => {
  await assertSucceeds(getDocs(query(published(as(null)), orderBy("publishAt", "desc"), limit(30))));
  await assertSucceeds(getDocs(query(published(as(ALICE)), where("shopId", "==", "s1"), orderBy("publishAt", "desc"))));
  await assertSucceeds(getDocs(query(collection(as(BOB), "drops"), where("userId", "==", BOB), orderBy("createdAt", "desc"))));
  // Without the publishAt bound the query could leak delayed drops.
  await assertFails(getDocs(query(collection(as(ALICE), "drops"), where("hidden", "==", false))));
});

test("dashboard stats query allowed for the owner only", async () => {
  const q = (db) => query(collection(db, "coffee_shops/s1/stats"), where("day", ">=", "20260901"));
  await assertSucceeds(getDocs(q(as(OWNER))));
  await assertFails(getDocs(q(as(ALICE))));
});

test("promo, regulars, comments and wants queries", async () => {
  await assertSucceeds(getDocs(query(collection(as(null), "promos"),
    where("shopId", "==", "s1"), where("endAt", ">", Timestamp.now()))));
  await assertSucceeds(getDocs(query(collection(as(null), "coffee_shops/s1/regulars_202609"),
    orderBy("checkins", "desc"), limit(10))));
  await assertSucceeds(getDocs(query(collection(as(null), "drops/published/comments"),
    orderBy("createdAt", "desc"))));
  await assertSucceeds(getDocs(collection(as(ALICE), "users/alice/wants")));
  await assertFails(getDocs(collection(as(BOB), "users/alice/wants")));
});
