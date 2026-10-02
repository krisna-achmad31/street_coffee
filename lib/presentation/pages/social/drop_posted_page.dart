import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/social.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../../injection_container.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/common.dart';
import '../../widgets/ui/receipt.dart';

class DropPostedPage extends StatefulWidget {
  final String dropId;
  const DropPostedPage({super.key, required this.dropId});

  @override
  State<DropPostedPage> createState() => _DropPostedPageState();
}

class _DropPostedPageState extends State<DropPostedPage> {
  final _cardKey = GlobalKey();
  late final _drop$ = sl<SocialRepository>().watchDrop(widget.dropId);
  bool _sharing = false;

  /// Renders the 270×480 card at 4× → 1080×1920 PNG (IG Story size).
  Future<File?> _renderCard() async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final ui.Image image = await boundary.toImage(pixelRatio: 4);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/street_coffee_${widget.dropId}.png');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file;
  }

  Future<void> _share(Drop d) async {
    setState(() => _sharing = true);
    try {
      final file = await _renderCard();
      if (file == null) {
        if (mounted) showAppSnack(context, 'Kartu belum siap, coba lagi', error: true);
        return;
      }
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: 'Kedai ke-${d.stampNumber} di paspor kopiku ☕ ${d.shopName} — Street Coffee',
      ));
    } catch (_) {
      if (mounted) showAppSnack(context, 'Gagal membagikan kartu', error: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 0.9,
            colors: [Color(0xFF1C2A10), AppColors.bg],
            stops: [0, 0.75],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<Drop?>(
            stream: _drop$,
            builder: (context, snap) {
              final d = snap.data;
              if (d == null) {
                final waiting = !snap.hasError &&
                    snap.connectionState == ConnectionState.waiting;
                if (waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return StateView(
                  icon: snap.hasError
                      ? Icons.wifi_off_rounded
                      : Icons.confirmation_number_outlined,
                  title: snap.hasError
                      ? 'Drop gagal dimuat'
                      : 'Drop tidak ditemukan',
                  message: snap.hasError
                      ? 'Drop kamu mungkin sudah terposting. Cek di Feed.'
                      : 'Drop ini sudah dihapus atau disembunyikan.',
                  danger: snap.hasError,
                  actionLabel: 'Ke Feed',
                  onAction: () => context.go(AppRouter.feed),
                );
              }
              final stamped = d.stampNumber > 0;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: OverlayIconButton(
                      icon: Icons.close_rounded,
                      background: AppColors.surface,
                      tooltip: 'Tutup',
                      onPressed: () => context.go(AppRouter.feed),
                    ),
                  ),
                  Text('Drop terposting! 🎉',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title.copyWith(fontSize: 22)),
                  const SizedBox(height: 6),
                  Text(
                    stamped
                        ? 'Stempel kedai ke-${d.stampNumber} masuk ke paspor kamu'
                        : 'Mengecek lokasi & menyiapkan stempel…',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.meta.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: ShareCard(drop: d),
                    ),
                  ),
                  if (d.isFirstAtShop) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x669FE444)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.flag_rounded,
                              size: 18, color: AppColors.onPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Badge baru: First Drop',
                                  style: AppTextStyles.body.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                              Text('Kamu orang pertama yang nge-Drop di sini',
                                  style: AppTextStyles.meta.copyWith(fontSize: 11)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Bagikan ke Story',
                    icon: Icons.ios_share_rounded,
                    loading: _sharing,
                    onPressed: () => _share(d),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Salin teks',
                        icon: Icons.link_rounded,
                        height: 44,
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(
                              text:
                                  '${d.userHandle} nge-Drop di ${d.shopName} ☕ Street Coffee'));
                          if (context.mounted) showAppSnack(context, 'Tersalin');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SecondaryButton(
                        label: 'Lihat Feed',
                        icon: Icons.local_fire_department_outlined,
                        height: 44,
                        onPressed: () => context.go(AppRouter.feed),
                      ),
                    ),
                  ]),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The IG Story card: 270×480 logical px (9:16), exported at 4×.
class ShareCard extends StatelessWidget {
  final Drop drop;
  const ShareCard({super.key, required this.drop});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 270,
        height: 480,
        child: Stack(fit: StackFit.expand, children: [
          NetImage(drop.coverUrl),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.28, 0.45, 0.85],
                colors: [
                  Color(0xB30E0E0E),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xF20E0E0E),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.coffee_rounded,
                        size: 13, color: AppColors.onPrimary),
                  ),
                  const SizedBox(width: 8),
                  Text('STREET COFFEE',
                      style: AppTextStyles.cardTitle.copyWith(
                          fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ]),
                const Spacer(),
                StampSeal(
                  number: drop.stampNumber > 0
                      ? drop.stampNumber.toString().padLeft(2, '0')
                      : '··',
                  bottom: Fmt.ddmm(drop.createdAt),
                  size: 68,
                  angle: -0.14,
                  fill: const Color(0x1A9FE444),
                ),
                const SizedBox(height: 10),
                Text('@${drop.userHandle} ngopi di',
                    style: AppTextStyles.body.copyWith(
                        fontSize: 12, color: AppColors.textSecondary)),
                Text(drop.shopName,
                    maxLines: 2,
                    style: AppTextStyles.display.copyWith(
                        fontSize: 26, height: 1, letterSpacing: -0.8)),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _pill(Icons.star_rounded, '${drop.rating}.0'),
                  if (drop.menuItem != null)
                    _pill(Icons.local_cafe_outlined, drop.menuItem!),
                  if (drop.vibe.isNotEmpty) _pill(Icons.bolt_rounded, drop.vibe),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x26FFFFFF))),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                          drop.isFirstAtShop ? '🏅 First Drop' : 'Paspor Kopi',
                          style: AppTextStyles.meta.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ),
                    Text('streetcoffee.id',
                        style: AppTextStyles.meta.copyWith(fontSize: 10)),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: AppColors.textPrimary),
          const SizedBox(width: 4),
          Text(text,
              style: AppTextStyles.meta.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ]),
      );
}
