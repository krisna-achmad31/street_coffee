import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/commerce.dart';
import '../../../domain/entities/social.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../../injection_container.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/explore/explore_bloc.dart';
import '../../blocs/location/location_bloc.dart';
import '../../widgets/cards/shop_cards.dart';
import '../../widgets/sheets/wa_confirm_sheet.dart';
import '../../widgets/ui/chips.dart';
import '../../widgets/ui/common.dart';
import '../../widgets/ui/location_problem.dart';

const homeVibes = [
  ('☕', 'Nongkrong Skena'),
  ('💬', 'Deep Talk'),
  ('🫗', 'Manual Brew'),
  ('💰', 'Kopi Hemat'),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _load(context.read<LocationBloc>().state);
  }

  void _load(LocationState s) {
    if (s is LocationLoaded) {
      context.read<ExploreBloc>().add(ExploreLoadShops(s.location));
    }
  }

  /// Keeps the spinner up until the reload actually finishes (max 15 s).
  Future<void> _refresh(BuildContext context) async {
    final loc = context.read<LocationBloc>().state;
    if (loc is! LocationLoaded) {
      context.read<LocationBloc>().add(LocationGetCurrent());
      return;
    }
    final bloc = context.read<ExploreBloc>()..add(ExploreRefresh(loc.location));
    await bloc.stream
        .firstWhere((s) => s is! ExploreLoading)
        .timeout(const Duration(seconds: 15), onTimeout: () => bloc.state);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationBloc, LocationState>(
      listener: (_, s) => _load(s),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverList.list(children: [
                    const _Header(),
                    const SizedBox(height: 24),
                    // Two lines per the design; shrinks slightly under 390 dp.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('Ngopi di mana\nmalam ini?',
                          style: AppTextStyles.display),
                    ),
                    const SizedBox(height: 24),
                    SearchTrigger(
                      onTap: () => context.go(AppRouter.explore),
                      onFilter: () => context.go(AppRouter.explore),
                    ),
                  ]),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _VibeRow()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                const SliverToBoxAdapter(child: _FeaturedSection()),
                const SliverToBoxAdapter(child: _DropsSection()),
                const SliverToBoxAdapter(child: _PassBanner()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Terdekat dari kamu',
                      action: 'Lihat semua',
                      onAction: () => context.go(AppRouter.explore),
                    ),
                  ),
                ),
                const _NearbyList(),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => context.push(AppRouter.pickLocation),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kedai di sekitar',
                    style: AppTextStyles.meta
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 4),
                BlocBuilder<LocationBloc, LocationState>(
                  builder: (context, s) => Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          s is LocationLoaded
                              ? s.location.displayName
                              : 'Mencari lokasi…',
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle,
                        ),
                      ),
                      const Icon(Icons.expand_more_rounded,
                          size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, s) => GestureDetector(
            onTap: () => context.go(AppRouter.profile),
            child: UserAvatar(
              url: s is AuthAuthenticated ? s.user.photoUrl : null,
              name: s is AuthAuthenticated ? s.user.displayName : '?',
              size: 40,
              radius: 12,
              borderColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _VibeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          VibePill(
            emoji: '✨',
            label: 'Semua',
            active: true,
            onTap: () => context.go(AppRouter.explore),
          ),
          for (final (e, l) in homeVibes) ...[
            const SizedBox(width: 8),
            VibePill(
              emoji: e,
              label: l,
              onTap: () => context.go(AppRouter.explore, extra: {'vibe': l}),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationBloc>().state;
    final explore = context.watch<ExploreBloc>().state;
    // Errors / empty / no location are explained once, by the nearby list.
    if (loc is LocationError ||
        explore is ExploreError ||
        explore is ExploreEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader(
              title: 'Featured Spots',
              action: 'Lihat semua',
              onAction: () => context.go(AppRouter.explore),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 260,
            child: BlocBuilder<ExploreBloc, ExploreState>(
              builder: (context, state) {
                if (state is! ExploreLoaded) {
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, __) =>
                        const Skeleton(width: 220, height: 260, radius: 20),
                  );
                }
                final featured =
                    state.shops.where((s) => s.isFeatured).take(6).toList();
                final list = featured.isEmpty
                    ? (state.shops.toList()
                          ..sort((a, b) => b.rating.compareTo(a.rating)))
                        .take(5)
                        .toList()
                    : featured;
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => FeaturedCard(
                    shop: list[i],
                    onTap: () =>
                        context.push('${AppRouter.detail}/${list[i].id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// "Lagi rame di-Drop 🔥" — trending drops of the week.
class _DropsSection extends StatelessWidget {
  const _DropsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Drop>>(
      stream: sl<SocialRepository>().watchFeed(FeedTab.trending),
      builder: (context, snap) {
        final drops = (snap.data ?? const <Drop>[]).take(8).toList();
        if (drops.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SectionHeader(
                  title: 'Lagi rame di-Drop 🔥',
                  action: 'Buka Feed',
                  onAction: () => context.go(AppRouter.feed),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: drops.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _DropTile(drop: drops[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DropTile extends StatelessWidget {
  final Drop drop;
  const _DropTile({required this.drop});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(AppRouter.feed),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 140,
          child: Stack(
            fit: StackFit.expand,
            children: [
              NetImage(drop.coverUrl),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1],
                    colors: [Colors.transparent, Color(0xE60E0E0E)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: UserAvatar(
                          url: drop.userPhotoUrl,
                          name: drop.userHandle,
                          size: 24,
                          radius: 7),
                    ),
                    const Spacer(),
                    Text(drop.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 13)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.coffee_rounded,
                            size: 11, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(Fmt.compact(drop.cheersCount),
                            style: AppTextStyles.meta.copyWith(
                                fontSize: 11,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600)),
                        Flexible(
                          child: Text(' · ${drop.userHandle}',
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.meta.copyWith(fontSize: 10)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hidden for members; guests see it too (tapping asks them to log in).
class _PassBanner extends StatelessWidget {
  const _PassBanner();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : null;
    return StreamBuilder<Membership>(
      stream: uid == null
          ? Stream.value(Membership.none)
          : sl<CommerceRepository>().watchMembership(uid),
      builder: (context, snap) {
        if (snap.data?.active == true) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () => context.push(AppRouter.streetPass),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFC8F56A)]),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.onPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.confirmation_number_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Street Pass: promo di kedai partner',
                            style: AppTextStyles.cardTitle.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onPrimary)),
                        Text('Coba gratis 7 hari',
                            style: AppTextStyles.meta.copyWith(
                                color: const Color(0xB30E0E0E),
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.onPrimary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NearbyList extends StatelessWidget {
  const _NearbyList();

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationBloc>().state;
    if (loc is LocationError) {
      return SliverToBoxAdapter(child: LocationProblemView(error: loc));
    }
    return BlocBuilder<ExploreBloc, ExploreState>(
      builder: (context, state) {
        if (state is ExploreLoading || state is ExploreInitial) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const Skeleton(height: 116, radius: 16),
            ),
          );
        }
        if (state is ExploreEmpty) {
          return SliverToBoxAdapter(
            child: StateView(
              icon: Icons.coffee_outlined,
              title: 'Belum ada kedai',
              message: state.message,
              actionLabel: 'Ganti lokasi',
              actionIcon: Icons.location_on_rounded,
              onAction: () => context.push(AppRouter.pickLocation),
            ),
          );
        }
        if (state is ExploreError) {
          return SliverToBoxAdapter(
            child: StateView(
              icon: Icons.wifi_off_rounded,
              title: 'Kedai gagal dimuat',
              message: state.message,
              danger: true,
              actionLabel: 'Coba lagi',
              actionIcon: Icons.refresh_rounded,
              onAction: () {
                final loc = context.read<LocationBloc>().state;
                if (loc is LocationLoaded) {
                  context
                      .read<ExploreBloc>()
                      .add(ExploreLoadShops(loc.location));
                }
              },
            ),
          );
        }
        final shops = (state as ExploreLoaded).shops.take(8).toList();
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: shops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => ShopCard(
              shop: shops[i],
              onTap: () => context.push('${AppRouter.detail}/${shops[i].id}'),
              onWhatsApp: shops[i].canOrderViaWa
                  ? () => showWaConfirmSheet(context, shop: shops[i])
                  : null,
            ),
          ),
        );
      },
    );
  }
}
