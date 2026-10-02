import 'package:url_launcher/url_launcher.dart';

enum LinkKind { instagram, tiktok, maps }

/// Turns what admins actually type into a launchable URL:
/// "@kedai", "kedai", "instagram.com/kedai", "https://…" all work.
/// Returns null when nothing sensible can be built.
Uri? socialUri(String? raw, LinkKind kind) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) return null;
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(s)) {
    final u = Uri.tryParse(s);
    return (u != null && u.host.isNotEmpty) ? u : null;
  }
  if (RegExp(r'^[\w-]+(\.[\w-]+)+(/|$)').hasMatch(s)) {
    return Uri.tryParse('https://$s');
  }
  final handle = s.replaceFirst('@', '');
  switch (kind) {
    case LinkKind.instagram:
      return RegExp(r'^[\w.]{1,30}$').hasMatch(handle)
          ? Uri.https('www.instagram.com', '/$handle/')
          : null;
    case LinkKind.tiktok:
      return RegExp(r'^[\w.]{2,24}$').hasMatch(handle)
          ? Uri.https('www.tiktok.com', '/@$handle')
          : null;
    case LinkKind.maps:
      // A bare address/place name: search it.
      return Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': s});
  }
}

/// Opens [uri] outside the app. Never throws; false when nothing could open it.
Future<bool> openExternal(Uri? uri) async {
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
