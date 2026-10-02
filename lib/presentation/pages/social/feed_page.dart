import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/failures.dart';
import '../../../domain/entities/social.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../../injection_container.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/cards/drop_ticket.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/chips.dart';
import '../../widgets/ui/common.dart';
import 'drop_sheets.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _repo = sl<SocialRepository>();
  FeedTab _tab = FeedTab.nearby;
  late Stream<List<Drop>> _feed$ = _repo.watchFeed(_tab, uid: _uid);
  late Stream<List<LiveCheckin>> _live$ = _repo.watchLiveCheckins();

  void _retry() => setState(() {
        _feed$ = _repo.watchFeed(_tab, uid: _uid);
        _live$ = _repo.watchLiveCheckins();
      });

  String? get _uid {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated ? s.user.uid : null;
  }

  void _setTab(FeedTab t) => setState(() {
        _tab = t;
        _feed$ = _repo.watchFeed(t, uid: _uid);
      });

  @override
  Widget build(BuildContext context) {
    // "Teman" depends on who is logged in.
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (a, b) =>
          (a is AuthAuthenticated ? a.user.uid : null) !=
          (b is AuthAuthenticated ? b.user.uid : null),
      listener: (_, __) => _retry(),
      child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Feed',
                trailing: Row(children: [
                  OverlayIconButton(
                    icon: Icons.notifications_none_rounded,
                    background: AppColors.surface,
                    tooltip: 'Notifikasi',
                    onPressed: () => context.push(
                        _uid == null ? AppRouter.login : AppRouter.notifications),
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Segmented<FeedTab>(
                  items: const [
                    (FeedTab.nearby, 'Sekitar', Icons.radar_rounded),
                    (FeedTab.friends, 'Teman', Icons.people_outline_rounded),
                    (FeedTab.trending, 'Trending', Icons.trending_up_rounded),
                  ],
                  value: _tab,
                  onChanged: _setTab,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _LiveRow(stream: _live$)),
            StreamBuilder<List<Drop>>(
              stream: _feed$,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList.separated(
                      itemCount: 2,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, __) => const Skeleton(height: 560, radius: 24),
                    ),
                  );
                }
                if (snap.hasError && !snap.hasData) {
                  return SliverToBoxAdapter(
                    child: StateView(
                      icon: Icons.wifi_off_rounded,
                      title: 'Feed gagal dimuat',
                      message: Failure.from(snap.error!,
                              'Cek koneksimu lalu coba lagi.')
                          .message,
                      danger: true,
                      actionLabel: 'Coba lagi',
                      actionIcon: Icons.refresh_rounded,
                      onAction: _retry,
                    ),
                  );
                }
                final drops = snap.data ?? const <Drop>[];
                if (_tab == FeedTab.friends && _uid == null) {
                  return SliverToBoxAdapter(
                    child: StateView(
                      icon: Icons.people_outline_rounded,
                      title: 'Masuk untuk lihat teman',
                      message:
                          'Drop dari orang yang kamu ikuti bakal muncul di sini.',
                      actionLabel: 'Masuk',
                      onAction: () => context.push(AppRouter.login),
                    ),
                  );
                }
                if (drops.isEmpty) {
                  return SliverToBoxAdapter(
                    child: StateView(
                      icon: Icons.confirmation_number_outlined,
                      title: _tab == FeedTab.friends
                          ? 'Belum ada Drop dari teman'
                          : 'Belum ada Drop di sekitar',
                      message:
                          'Jadi yang pertama! Drop pertama di sebuah kedai dapat badge First Drop.',
                      actionLabel: 'Buat Drop',
                      actionIcon: Icons.add_rounded,
                      onAction: () => context.push(
                          _uid == null ? AppRouter.login : AppRouter.newDrop),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  sliver: SliverList.separated(
                    itemCount: drops.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => ConnectedDropTicket(drop: drops[i]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// DropTicket wired to the repository (cheers, wants, comments, report).
class ConnectedDropTicket extends StatelessWidget {
  final Drop drop;
  const ConnectedDropTicket({super.key, required this.drop});

  @override
  Widget build(BuildContext context) {
    final repo = sl<SocialRepository>();
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : null;
    void needLogin() => context.push(AppRouter.login);
    return StreamBuilder<bool>(
      stream: uid == null ? Stream.value(false) : repo.watchCheered(drop.id, uid),
      builder: (context, cheered) => StreamBuilder<bool>(
        stream: uid == null ? Stream.value(false) : repo.watchWant(uid, drop.shopId),
        builder: (context, wanted) => DropTicket(
          drop: drop,
          cheered: cheered.data ?? false,
          wanted: wanted.data ?? false,
          onCheers: uid == null
              ? needLogin
              : () async {
                  final r = await repo.setCheers(
                      drop.id, uid, !(cheered.data ?? false));
                  if (context.mounted) _report(context, r);
                },
          onWant: uid == null
              ? needLogin
              : () async {
                  final r = await repo.setWant(
                      uid, drop.shopId, !(wanted.data ?? false));
                  if (context.mounted) _report(context, r);
                },
          onComment: () => showDropComments(context, drop),
          onShare: () => SharePlus.instance.share(ShareParams(
              text:
                  '${drop.userHandle} nge-Drop di ${drop.shopName} ☕ — cek di Street Coffee')),
          onShop: drop.shopId.isEmpty
              ? null
              : () => context.push('${AppRouter.detail}/${drop.shopId}'),
          onMore: uid == null
              ? null
              : () => showReportSheet(context, drop: drop, reporterUid: uid),
        ),
      ),
    );
  }
}

void _report(BuildContext context, Either<Failure, void> r) {
  r.fold((f) => showAppSnack(context, f.message, error: true), (_) {});
}

class _LiveRow extends StatelessWidget {
  final Stream<List<LiveCheckin>> stream;
  const _LiveRow({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LiveCheckin>>(
      stream: stream,
      builder: (context, snap) {
        final live = snap.data ?? const <LiveCheckin>[];
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.primary, blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const MonoText('LAGI DI KEDAI SEKARANG',
                      size: 11, weight: FontWeight.w700, letterSpacing: 1),
                ]),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 112,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _checkinCard(context),
                    for (final l in live) ...[
                      const SizedBox(width: 10),
                      _liveCard(context, l),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _checkinCard(BuildContext context) => GestureDetector(
        onTap: () {
          final loggedIn = context.read<AuthBloc>().state is AuthAuthenticated;
          context.push(loggedIn ? AppRouter.newDrop : AppRouter.login);
        },
        child: Container(
          width: 96,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    size: 18, color: AppColors.onPrimary),
              ),
              const SizedBox(height: 8),
              Text('Check-in',
                  style: AppTextStyles.meta.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
        ),
      );

  Widget _liveCard(BuildContext context, LiveCheckin l) => GestureDetector(
        onTap: () => context.push('${AppRouter.detail}/${l.shopId}'),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                NetImage(l.shopImageUrl,
                    width: 36, height: 36, radius: BorderRadius.circular(10)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.shopName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle
                          .copyWith(fontSize: 13, height: 1.1)),
                ),
              ]),
              const Spacer(),
              SizedBox(
                height: 26,
                child: Stack(children: [
                  for (var i = 0; i < l.userPhotos.length; i++)
                    Positioned(
                      left: i * 16.0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                        child: UserAvatar(
                            url: l.userPhotos[i],
                            name: l.handles.isEmpty ? '?' : l.handles.first,
                            size: 22,
                            radius: 6),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              MonoText(
                l.handles.length == 1
                    ? l.handles.first.toUpperCase()
                    : '${l.handles.length} ORANG',
                size: 10,
                weight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      );
}
