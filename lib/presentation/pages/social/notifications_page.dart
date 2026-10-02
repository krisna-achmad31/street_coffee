import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/social.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../../injection_container.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/ui/chips.dart';
import '../../widgets/ui/common.dart';

enum _Filter { all, cheers, comment, promo }

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _repo = sl<SocialRepository>();
  _Filter _filter = _Filter.all;
  Stream<List<AppNotification>>? _items$;
  String? _uid;

  @override
  void initState() {
    super.initState();
    final s = context.read<AuthBloc>().state;
    if (s is AuthAuthenticated) {
      _uid = s.user.uid;
      _items$ = _repo.watchNotifications(_uid!);
    }
  }

  static const _kindStyle = {
    NotificationKind.cheers: (Icons.coffee_rounded, AppColors.primary),
    NotificationKind.comment: (Icons.mode_comment_rounded, AppColors.primary),
    NotificationKind.promo: (Icons.confirmation_number_rounded, AppColors.primary),
    NotificationKind.follow: (Icons.person_add_rounded, AppColors.primary),
    NotificationKind.badge: (Icons.military_tech_rounded, AppColors.star),
    NotificationKind.regulars: (Icons.emoji_events_rounded, AppColors.star),
  };

  bool _match(AppNotification n) => switch (_filter) {
        _Filter.all => true,
        _Filter.cheers => n.kind == NotificationKind.cheers,
        _Filter.comment => n.kind == NotificationKind.comment,
        _Filter.promo => n.kind == NotificationKind.promo,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          ScreenHeader(
            title: 'Notifikasi',
            back: true,
            trailing: _uid == null
                ? null
                : TextButton(
                    onPressed: () async {
                      final r = await _repo.markNotificationsRead(_uid!);
                      if (!context.mounted) return;
                      r.fold((f) => showAppSnack(context, f.message, error: true),
                          (_) {});
                    },
                    child: Text('Tandai dibaca',
                        style: AppTextStyles.badge.copyWith(fontSize: 12)),
                  ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final (f, l) in const [
                  (_Filter.all, 'Semua'),
                  (_Filter.cheers, 'Cheers'),
                  (_Filter.comment, 'Komentar'),
                  (_Filter.promo, 'Promo'),
                ]) ...[
                  AppFilterChip(
                    label: l,
                    active: _filter == f,
                    showChevron: false,
                    onTap: () => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _items$ == null
                ? const StateView(
                    icon: Icons.notifications_none_rounded,
                    title: 'Masuk dulu',
                    message: 'Notifikasi Cheers, komentar, dan promo muncul di sini.',
                  )
                : StreamBuilder<List<AppNotification>>(
                    stream: _items$,
                    builder: (context, snap) {
                      if (snap.hasError && !snap.hasData) {
                        return StateView(
                          icon: Icons.wifi_off_rounded,
                          title: 'Notifikasi gagal dimuat',
                          message: 'Cek koneksimu lalu coba lagi.',
                          danger: true,
                          actionLabel: 'Coba lagi',
                          onAction: () => setState(() =>
                              _items$ = _repo.watchNotifications(_uid!)),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final items = snap.data!.where(_match).where((n) => n.text.isNotEmpty).toList();
                      if (items.isEmpty) {
                        return const StateView(
                          icon: Icons.notifications_none_rounded,
                          title: 'Belum ada notifikasi',
                          message: 'Nge-Drop dan kasih Cheers biar rame.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _tile(items[i]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _tile(AppNotification n) {
    final (icon, color) = _kindStyle[n.kind]!;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: n.read ? Colors.transparent : const Color(0x0D9FE444),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(clipBehavior: Clip.none, children: [
            UserAvatar(url: n.actorPhotoUrl, name: '•', size: 44, radius: 12),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 2),
                ),
                child: Icon(icon, size: 10, color: AppColors.onPrimary),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.text, style: AppTextStyles.body.copyWith(fontSize: 13)),
              const SizedBox(height: 3),
              Text(Fmt.timeAgo(n.createdAt),
                  style: AppTextStyles.meta.copyWith(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
        if (n.thumbUrl != null) ...[
          const SizedBox(width: 10),
          NetImage(n.thumbUrl!, width: 44, height: 44, radius: BorderRadius.circular(10)),
        ],
      ]),
    );
  }
}
