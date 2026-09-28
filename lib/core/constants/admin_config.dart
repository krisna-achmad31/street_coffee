/// Phase 1: Hardcode admin UID.
/// Cara dapat UID kamu:
/// 1. Login ke app sekali dengan Google
/// 2. Buka Firebase Console → Authentication → Users
/// 3. Copy UID dari kolom "User UID"
/// 4. Paste di sini, lalu rebuild
class AdminConfig {
  AdminConfig._();

  // ⚠️  GANTI dengan UID Google kamu setelah pertama kali login
  static const String adminUid = 'uSR6zFYKnSOMzlTYLNURchYQTw43';

  static bool isAdmin(String? uid) {
    if (uid == null) return false;
    return uid == adminUid;
  }
}
