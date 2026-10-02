import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Tolerant readers for Firestore / callable payloads.
///
/// Documents are written by the app, Cloud Functions and admins typing in the
/// Firebase console, so field types drift: `4` vs `4.0` vs `"4"`, Timestamp vs
/// epoch millis vs ISO string, a single string where a list was expected.
/// Every reader returns a sane default instead of throwing, so one malformed
/// field never takes down a whole screen.
class Json {
  final Map<String, dynamic> _m;
  const Json(this._m);

  factory Json.of(Object? data) => Json(asMap(data));

  Map<String, dynamic> get raw => _m;

  String str(String k, [String fallback = '']) => asString(_m[k]) ?? fallback;

  /// Trimmed, or null when missing/blank.
  String? strOrNull(String k) {
    final s = asString(_m[k])?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  int integer(String k, [int fallback = 0]) => asInt(_m[k]) ?? fallback;
  int? intOrNull(String k) => asInt(_m[k]);
  double dbl(String k, [double fallback = 0]) => asDouble(_m[k]) ?? fallback;
  double? dblOrNull(String k) => asDouble(_m[k]);
  bool boolean(String k, [bool fallback = false]) => asBool(_m[k]) ?? fallback;
  DateTime? date(String k) => asDate(_m[k]);
  List<String> strings(String k) => asStringList(_m[k]);
  List<Json> list(String k) => asList(_m[k]).map(Json.of).toList();
  Json obj(String k) => Json.of(_m[k]);

  // ── Scalar coercion ────────────────────────────────────────────────────────

  static Map<String, dynamic> asMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      return {for (final e in v.entries) e.key.toString(): e.value};
    }
    return const {};
  }

  static List<Object?> asList(Object? v) => v is List ? v : const [];

  static String? asString(Object? v) {
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    return null;
  }

  static int? asInt(Object? v) {
    if (v is int) return v;
    if (v is double) return v.isFinite ? v.round() : null;
    if (v is String) {
      final s = v.trim();
      return int.tryParse(s) ?? asInt(double.tryParse(s.replaceAll(',', '.')));
    }
    return null;
  }

  static double? asDouble(Object? v) {
    if (v is num) return v.isFinite ? v.toDouble() : null;
    if (v is String) return asDouble(double.tryParse(v.trim().replaceAll(',', '.')));
    return null;
  }

  static bool? asBool(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      switch (v.trim().toLowerCase()) {
        case 'true' || '1' || 'yes' || 'ya':
          return true;
        case 'false' || '0' || 'no' || 'tidak':
          return false;
      }
    }
    return null;
  }

  /// Timestamp, DateTime, epoch seconds/millis, or ISO-8601 string.
  static DateTime? asDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      // Below ~1e11 it can only be seconds (millis that small = 1973).
      return DateTime.fromMillisecondsSinceEpoch(v < 100000000000 ? v * 1000 : v);
    }
    if (v is double && v.isFinite) return asDate(v.round());
    if (v is String) return DateTime.tryParse(v.trim());
    return null;
  }

  /// A list of non-blank, de-duplicated strings. A lone string becomes `[s]`.
  static List<String> asStringList(Object? v) {
    if (v is String) return v.trim().isEmpty ? const [] : [v.trim()];
    final out = <String>[];
    for (final e in asList(v)) {
      final s = asString(e)?.trim();
      if (s != null && s.isNotEmpty && !out.contains(s)) out.add(s);
    }
    return out;
  }

  /// Only http(s) URLs; anything else would just be a broken image.
  static String url(Object? v) {
    final s = asString(v)?.trim() ?? '';
    return s.startsWith('https://') || s.startsWith('http://') ? s : '';
  }
}

/// Maps every document, skipping (and logging) the ones that still fail, so a
/// single bad document never empties a whole list or kills a stream.
List<T> parseEach<S, T>(Iterable<S> items, T Function(S) parse) {
  final out = <T>[];
  for (final item in items) {
    try {
      out.add(parse(item));
    } catch (e, st) {
      final id = item is DocumentSnapshot ? item.reference.path : '$item';
      debugPrint('Skipping unparseable $id: $e\n$st');
    }
  }
  return out;
}
