import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Short code appended to every WhatsApp order (PRD: lubang #3).
///
/// Deterministic per (user, shop, day) so re-opening WA the same day keeps
/// the same lead instead of inflating the count. The owner pastes it on the
/// dashboard to mark the lead as "jadi beli".
class AttributionCode {
  AttributionCode._();

  static const String _alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  static String dayKey(DateTime t) {
    final l = t.toLocal();
    return '${l.year}${l.month.toString().padLeft(2, '0')}${l.day.toString().padLeft(2, '0')}';
  }

  /// [visitorId] is the Firebase uid, or an anonymous install id for guests.
  static String generate({
    required String visitorId,
    required String shopId,
    required DateTime at,
  }) {
    final digest =
        sha256.convert(utf8.encode('$visitorId|$shopId|${dayKey(at)}')).bytes;
    final bits = (digest[0] << 12) | (digest[1] << 4) | (digest[2] >> 4);
    final code = StringBuffer();
    for (var i = 0; i < 4; i++) {
      code.write(_alphabet[(bits >> (5 * (3 - i))) & 31]);
    }
    return 'SC-$code';
  }

  static final RegExp pattern = RegExp(r'SC-[2-9A-HJ-NP-Z]{4}');

  /// Accepts "sc 7f3k", "SC-7F3K", "(kode: SC-7F3K)".
  static String? parse(String input) {
    final cleaned = input.toUpperCase().replaceAll(' ', '-');
    final direct = pattern.firstMatch(cleaned);
    if (direct != null) return direct.group(0);
    final bare = RegExp(r'[2-9A-HJ-NP-Z]{4}').firstMatch(
        cleaned.replaceAll('SC', '').replaceAll('-', ''));
    return bare == null ? null : 'SC-${bare.group(0)}';
  }
}
