/// Small display helpers shared across screens.
class Fmt {
  Fmt._();

  /// 18000 → "Rp18k", 1250000 → "Rp1,3jt"
  static String rupiahShort(int value) {
    if (value >= 1000000) {
      return 'Rp${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')}jt';
    }
    if (value >= 1000) return 'Rp${(value / 1000).round()}k';
    return 'Rp$value';
  }

  /// 30000 → "Rp30.000"
  static String rupiah(int value) {
    final s = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
      out.write(s[i]);
    }
    return 'Rp$out';
  }

  /// 1234 → "1,2rb"
  static String compact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')}jt';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')}rb';
    }
    return '$value';
  }

  static String timeAgo(DateTime t, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(t);
    if (d.inMinutes < 1) return 'baru saja';
    if (d.inMinutes < 60) return '${d.inMinutes} mnt lalu';
    if (d.inHours < 24) return '${d.inHours} jam lalu';
    if (d.inDays < 7) return '${d.inDays} hari lalu';
    return '${t.day}/${t.month}/${t.year}';
  }

  static String hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

  static String ddmm(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}·${t.month.toString().padLeft(2, '0')}';

  static String stars(int rating) =>
      List.generate(5, (i) => i < rating ? '★' : '☆').join();
}
