class FirebasePaths {
  FirebasePaths._();

  // Firestore
  static const String shops = 'coffee_shops';
  static String shopComments(String shopId) => 'coffee_shops/$shopId/comments';

  // v2 — social
  static const String drops = 'drops';
  static String dropComments(String dropId) => 'drops/$dropId/comments';
  static String dropCheers(String dropId) => 'drops/$dropId/cheers';
  static const String users = 'users';
  static String userStamps(String uid) => 'users/$uid/stamps';
  static String userNotifications(String uid) => 'users/$uid/notifications';
  static String userWants(String uid) => 'users/$uid/wants';
  static String followers(String uid) => 'users/$uid/followers';
  static const String reports = 'reports';

  // v2 — commerce
  static const String promos = 'promos';
  static const String redeemIntents = 'redeem_intents';
  static const String redemptions = 'redemptions';
  static const String memberships = 'memberships';
  static const String shopClaims = 'shop_claims';

  // Owner-only data lives under the shop so rules can check ownership by path.
  static String shopStats(String shopId) => 'coffee_shops/$shopId/stats';
  static String shopLeads(String shopId) => 'coffee_shops/$shopId/leads';
  static String shopFollowers(String shopId) => 'coffee_shops/$shopId/followers';
  static String revenueShare(String yyyymm) => 'revenue_share/$yyyymm/shops';

  // Storage
  static String shopCover(String shopId) => 'shops/$shopId/cover.jpg';
  static String shopGallery(String shopId, String filename) =>
      'shops/$shopId/gallery/$filename';
  static String menuPhoto(String shopId, String filename) =>
      'shops/$shopId/menu/$filename';
  static String dropPhoto(String uid, String dropId, int i) =>
      'drops/$uid/$dropId/$i.jpg';

  // RTDB
  static String shopPresence(String shopId) => 'presence/shops/$shopId';
  static String shopCommentCount(String shopId) =>
      'counters/comments/$shopId';
}
