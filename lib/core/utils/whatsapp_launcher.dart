import 'package:url_launcher/url_launcher.dart';

class WhatsAppLauncher {
  WhatsAppLauncher._();

  /// Launch WhatsApp with pre-filled message
  /// [phone] must be in international format without '+', e.g. '6281234567890'
  static Future<bool> openChat({
    required String phone,
    required String message,
  }) async {
    final encoded = Uri.encodeComponent(message);
    final waUrl = Uri.parse('https://wa.me/$phone?text=$encoded');

    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Build pre-filled order message
  static String buildOrderMessage({
    required String shopName,
    required String? menuItem,
  }) {
    final appSource = 'Street Coffee';
    if (menuItem != null && menuItem.isNotEmpty) {
      return 'Halo $shopName, saya dari aplikasi $appSource. Mau pesan: $menuItem.';
    }
    return 'Halo $shopName, saya dari aplikasi $appSource. Apakah masih buka?';
  }
}
