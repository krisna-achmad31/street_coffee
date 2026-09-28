class FirebasePaths {
  FirebasePaths._();

  // Firestore
  static const String shops = 'coffee_shops';
  static String shopComments(String shopId) => 'coffee_shops/$shopId/comments';

  // Storage
  static String shopCover(String shopId) => 'shops/$shopId/cover.jpg';
  static String shopGallery(String shopId, String filename) =>
      'shops/$shopId/gallery/$filename';
  static String menuPhoto(String shopId, String filename) =>
      'shops/$shopId/menu/$filename';

  // RTDB
  static String shopPresence(String shopId) => 'presence/shops/$shopId';
  static String shopCommentCount(String shopId) =>
      'counters/comments/$shopId';
}
