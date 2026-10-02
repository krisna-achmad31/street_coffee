import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Rotating redeem code shown to the cashier (PRD: lubang #1).
///
/// code = base32(HMAC-SHA256(memberSecret, "promoId:window")[0..30 bits])
/// window = floor(unixSeconds / 30)
///
/// The same algorithm lives in functions/src/codes.ts; the server is the only
/// place a code is accepted (window and window-1, to absorb clock drift).
class RedeemCode {
  RedeemCode._();

  static const int periodSeconds = 30;
  static const int length = 6;

  /// No 0/O, 1/I — easy to read aloud at a busy counter.
  static const String alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  static int windowFor(DateTime t) =>
      t.toUtc().millisecondsSinceEpoch ~/ 1000 ~/ periodSeconds;

  static int secondsLeft(DateTime t) =>
      periodSeconds - (t.toUtc().millisecondsSinceEpoch ~/ 1000) % periodSeconds;

  static String generate({
    required String secret,
    required String promoId,
    required DateTime at,
  }) =>
      forWindow(secret: secret, promoId: promoId, window: windowFor(at));

  static String forWindow({
    required String secret,
    required String promoId,
    required int window,
  }) {
    final mac = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode('$promoId:$window'))
        .bytes;
    // 30 bits → 6 chars × 5 bits.
    var bits = (mac[0] << 22) | (mac[1] << 14) | (mac[2] << 6) | (mac[3] >> 2);
    final out = StringBuffer();
    for (var i = 0; i < length; i++) {
      out.write(alphabet[(bits >> (5 * (length - 1 - i))) & 31]);
    }
    return out.toString();
  }

  /// QR payload scanned by the cashier app: version|uid|promoId|code.
  static String qrPayload({
    required String uid,
    required String promoId,
    required String code,
  }) =>
      'SC1|$uid|$promoId|$code';

  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
}
