import 'package:url_launcher/url_launcher.dart';

class WhatsAppLauncher {
  WhatsAppLauncher._();

  /// Launch WhatsApp with pre-filled message
  /// [phone] must be in international format without '+', e.g. '6281234567890'
  static Future<bool> openChat({
    required String phone,
    required String message,
  }) async {
    final digits = normalizePhone(phone);
    if (digits.isEmpty) return false;
    final waUrl = Uri.https('wa.me', '/$digits', {'text': message});
    // canLaunchUrl lies on Android 11+ without a <queries> entry, so just try.
    try {
      return await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// "0812-3456 789" / "+62 812…" / "812…" → "62812…"; '' if not a number.
  static String normalizePhone(String raw) {
    var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('0')) d = '62${d.substring(1)}';
    if (d.startsWith('8')) d = '62$d';
    return d.length >= 9 && d.length <= 15 ? d : '';
  }

  /// Pre-filled order message. [attributionCode] is always appended on its
  /// own line so the shop can match the chat to a Street Coffee lead.
  static String buildOrderMessage({
    required String shopName,
    required String? menuItem,
    int quantity = 1,
    String? attributionCode,
  }) {
    const appSource = 'Street Coffee';
    final body = (menuItem != null && menuItem.isNotEmpty)
        ? 'Halo $shopName 👋 saya dari aplikasi $appSource. '
            'Mau pesan ${quantity > 1 ? '$quantity× ' : ''}$menuItem, masih bisa?'
        : 'Halo $shopName 👋 saya dari aplikasi $appSource. Apakah masih buka?';
    return attributionCode == null ? body : '$body\n(kode: $attributionCode)';
  }
}
