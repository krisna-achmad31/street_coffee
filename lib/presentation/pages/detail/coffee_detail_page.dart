import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/firebase_paths.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/links.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../../domain/entities/commerce.dart';
import '../../../domain/entities/social.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../../injection_container.dart';
import '../../blocs/admin/admin_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/comment/comment_bloc.dart';
import '../../blocs/detail/detail_bloc.dart';
import '../../blocs/location/location_bloc.dart';
import '../../widgets/cards/shop_cards.dart';
import '../../widgets/common/comment_section.dart';
import '../../widgets/sheets/wa_confirm_sheet.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/chips.dart';
import '../../widgets/ui/common.dart';

class CoffeeDetailPage extends StatefulWidget {
  final String shopId;
  const CoffeeDetailPage({super.key, required this.shopId});

  @override
  State<CoffeeDetailPage> createState() => _CoffeeDetailPageState();
}

enum _Tab { review, drops, regulars }

class _CoffeeDetailPageState extends State<CoffeeDetailPage> {
  bool? _rtdbIsOpen;
  StreamSubscription<DatabaseEvent>? _presence;
  _Tab _tab = _Tab.review;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    context.read<DetailBloc>().add(DetailLoadShop(widget.shopId));
    sl<CommerceRepository>().recordShopView(widget.shopId);
    _watchPresence();
  }

  void _watchPresence() {
    // Presence is optional: anything unreadable falls back to Firestore.
    // No RTDB registered (widget tests) means no presence at all.
    if (!sl.isRegistered<FirebaseDatabase>()) return;
    final DatabaseReference ref;
    try {
      ref = sl<FirebaseDatabase>().ref(FirebasePaths.shopPresence(widget.shopId));
    } catch (e) {
      debugPrint('presence: $e');
      return;
    }
    _presence = ref.onValue.listen((event) {
      final value = event.snapshot.value;
      final raw = value is Map ? value['isOpen'] : null;
      final isOpen = raw is bool ? raw : (raw is num ? raw != 0 : null);
      if (isOpen != null && mounted) setState(() => _rtdbIsOpen = isOpen);
    }, onError: (Object e) => debugPrint('presence: $e'));
  }

  @override
  void dispose() {
    _presence?.cancel();
    super.dispose();
  }

  String? get _uid {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated ? s.user.uid : null;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<CommentBloc>()),
        BlocProvider(create: (_) => sl<AdminBloc>()),
      ],
      child: BlocBuilder<DetailBloc, DetailState>(
        builder: (context, state) {
          if (state is DetailLoaded) {
            final loc = context.watch<LocationBloc>().state;
            final km = loc is LocationLoaded && state.shop.hasLocation
                ? Geolocator.distanceBetween(
                        loc.location.latitude,
                        loc.location.longitude,
                        state.shop.latitude,
                        state.shop.longitude) /
                    1000
                : null;
            return _buildDetail(context,
                state.shop.copyWith(
                    isOpen: _rtdbIsOpen == null
                        ? null
                        : _rtdbIsOpen! &&
                            CoffeeShop.withinHours(state.shop.openFrom,
                                state.shop.openUntil, DateTime.now()),
                    distanceKm: km));
          }
          if (state is DetailError) {
            return Scaffold(
              body: SafeArea(
                child: Column(children: [
                  const ScreenHeader(title: '', back: true),
                  Expanded(
                    child: StateView(
                      icon: Icons.wifi_off_rounded,
                      title: 'Kedai tidak bisa dimuat',
                      message: state.message,
                      danger: true,
                      actionLabel: 'Coba lagi',
                      actionIcon: Icons.refresh_rounded,
                      onAction: () => context
                          .read<DetailBloc>()
                          .add(DetailLoadShop(widget.shopId)),
                    ),
                  ),
                ]),
              ),
            );
          }
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        },
      ),
    );
  }

  Widget _buildDetail(BuildContext context, CoffeeShop shop) {
    final auth = context.watch<AuthBloc>().state;
    final isAdmin = auth is AuthAuthenticated && auth.user.isAdmin;
    // Only links we can actually open; a bad value hides the button.
    final links = [
      (socialUri(shop.instagramUrl, LinkKind.instagram), Icons.camera_alt_outlined, 'Instagram'),
      (socialUri(shop.tiktokUrl, LinkKind.tiktok), Icons.music_note_rounded, 'TikTok'),
      (socialUri(shop.googleMapsUrl, LinkKind.maps) ??
          (shop.hasLocation
              ? Uri.https('www.google.com', '/maps/search/', {
                  'api': '1',
                  'query': '${shop.latitude},${shop.longitude}',
                })
              : null), Icons.map_outlined, 'Maps'),
    ].where((l) => l.$1 != null).map((l) => (l.$1!, l.$2, l.$3)).toList();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _hero(context, shop, isAdmin)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            sliver: SliverList.list(children: [
              if (isAdmin) ...[_adminBanner(), const SizedBox(height: 20)],
              Text(shop.displayName,
                  style: AppTextStyles.title.copyWith(letterSpacing: -0.4)),
              const SizedBox(height: 10),
              Row(children: [
                StatusBadge(
                    isOpen: shop.isOpen,
                    text: shop.isOpen ? 'Buka sekarang' : 'Tutup'),
                const SizedBox(width: 8),
                Text(shop.hoursText,
                    style: AppTextStyles.meta.copyWith(fontSize: 13)),
              ]),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 15, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(shop.address,
                        style: AppTextStyles.meta.copyWith(fontSize: 13, height: 1.4)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _stats(shop),
              _PromoStrip(shop: shop),
              if (shop.description.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(shop.description,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary, height: 1.5)),
              ],
              if (shop.vibes.isNotEmpty || shop.vibe.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Vibe', style: AppTextStyles.section),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final v in {shop.vibe, ...shop.vibes}.where((v) => v.isNotEmpty))
                    VibePill(emoji: vibeEmoji[v] ?? '☕', label: v),
                ]),
              ],
              if (shop.facilities.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Fasilitas', style: AppTextStyles.section),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 12,
                  children: [for (final f in shop.facilities) FacilityItem(f)],
                ),
              ],
              if (shop.menuFavorites.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Menu Favorit', style: AppTextStyles.section),
                const SizedBox(height: 12),
                SizedBox(
                  height: 170,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: shop.menuFavorites.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) =>
                        _menuItem(context, shop, shop.menuFavorites[i]),
                  ),
                ),
              ],
              if (links.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Temukan juga di', style: AppTextStyles.section),
                const SizedBox(height: 12),
                Row(children: [
                  for (final (uri, icon, label) in links)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SecondaryButton(
                          label: label,
                          icon: icon,
                          height: 44,
                          onPressed: () async {
                            if (!await openExternal(uri) && context.mounted) {
                              showAppSnack(context, 'Link tidak bisa dibuka',
                                  error: true);
                            }
                          },
                        ),
                      ),
                    ),
                ]),
              ],
              const SizedBox(height: 28),
              Segmented<_Tab>(
                items: const [
                  (_Tab.review, 'Review', null),
                  (_Tab.drops, 'Drops', null),
                  (_Tab.regulars, 'Regulars', null),
                ],
                value: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
              const SizedBox(height: 16),
              switch (_tab) {
                _Tab.review => CommentSection(shopId: shop.id),
                _Tab.drops => _ShopDrops(shopId: shop.id),
                _Tab.regulars => _Regulars(shopId: shop.id),
              },
            ]),
          ),
        ],
      ),
      bottomNavigationBar: _bottomCta(context, shop),
    );
  }

  Widget _hero(BuildContext context, CoffeeShop shop, bool isAdmin) {
    final images = [
      if (shop.imageUrl.isNotEmpty) shop.imageUrl,
      ...shop.galleryUrls,
    ];
    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: [
          images.isEmpty
              ? const NetImage('')
              : PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => NetImage(images[i]),
                ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.35, 0.6, 1],
                  colors: [
                    Color(0x990E0E0E),
                    Colors.transparent,
                    Colors.transparent,
                    AppColors.bg
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      OverlayIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Kembali',
                          onPressed: () => context.pop()),
                      const Spacer(),
                      if (isAdmin) ...[
                        _openToggle(shop),
                        const SizedBox(width: 8),
                        OverlayIconButton(
                          icon: Icons.edit_rounded,
                          tooltip: 'Edit kedai',
                          onPressed: () =>
                              context.push(AppRouter.adminEditShop, extra: shop),
                        ),
                      ] else ...[
                        OverlayIconButton(
                          icon: Icons.share_rounded,
                          tooltip: 'Bagikan',
                          onPressed: () => SharePlus.instance.share(ShareParams(
                              text: [
                            '${shop.displayName} di Street Coffee',
                            if (shop.address.isNotEmpty) shop.address,
                          ].join(' — '))),
                        ),
                        const SizedBox(width: 8),
                        _WantButton(shopId: shop.id, uid: _uid),
                      ],
                    ],
                  ),
                  const Spacer(),
                  if (images.length > 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.overlay,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${_page + 1} / ${images.length}',
                            style: AppTextStyles.meta.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _openToggle(CoffeeShop shop) {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, _) => Container(
        height: 40,
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: AppColors.overlay,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Text(shop.isOpen ? 'Buka' : 'Tutup',
              style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: shop.isOpen ? AppColors.primary : AppColors.closed)),
          Switch(
            value: shop.isOpen,
            onChanged: (v) {
              context
                  .read<AdminBloc>()
                  .add(AdminToggleOpen(shopId: shop.id, isOpen: v));
              setState(() => _rtdbIsOpen = v);
            },
          ),
        ]),
      ),
    );
  }

  Widget _adminBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x669FE444)),
        ),
        child: Row(children: [
          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mode admin',
                    style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                Text('Status buka tersinkron real-time ke semua user.',
                    style: AppTextStyles.meta),
              ],
            ),
          ),
        ]),
      );

  Widget _stats(CoffeeShop shop) {
    Widget stat(IconData icon, Color c, String v, String l) => Expanded(
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 14, color: c),
              const SizedBox(width: 5),
              Flexible(
                child: Text(v,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(l,
                style: AppTextStyles.meta
                    .copyWith(fontSize: 11, color: AppColors.textMuted)),
          ]),
        );
    Widget div() => Container(width: 1, height: 36, color: AppColors.divider);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        stat(Icons.star_rounded, AppColors.star, shop.rating.toStringAsFixed(1),
            '${shop.reviewCount} review'),
        div(),
        stat(Icons.near_me_rounded, AppColors.primary,
            shop.distanceText.isEmpty ? '-' : shop.distanceText, 'dari kamu'),
        div(),
        stat(Icons.account_balance_wallet_rounded, AppColors.primary,
            shop.priceRange.isEmpty ? '-' : shop.priceRange, 'per orang'),
      ]),
    );
  }

  Widget _menuItem(BuildContext context, CoffeeShop shop, MenuFavorite m) {
    return GestureDetector(
      onTap: shop.canOrderViaWa
          ? () => showWaConfirmSheet(context, shop: shop, menu: m)
          : null,
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              NetImage(m.imageUrl,
                  width: 132,
                  height: 112,
                  radius: BorderRadius.circular(14),
                  fallbackIcon: Icons.local_cafe_outlined),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.add_rounded,
                      size: 18, color: AppColors.onPrimary),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(m.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body
                    .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
            if (m.price != null)
              Text(Fmt.rupiahShort(m.price!),
                  style: AppTextStyles.cardTitle
                      .copyWith(fontSize: 13, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _bottomCta(BuildContext context, CoffeeShop shop) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(children: [
        SizedBox(
          width: 100,
          child: SecondaryButton(
            label: 'Drop',
            icon: Icons.photo_camera_outlined,
            onPressed: () => context.push(
                _uid == null ? AppRouter.login : AppRouter.newDrop,
                extra: shop),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PrimaryButton(
            label: shop.canOrderViaWa ? 'Pesan via WA' : 'WA belum tersedia',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: shop.canOrderViaWa
                ? () => showWaConfirmSheet(context, shop: shop)
                : null,
          ),
        ),
      ]),
    );
  }
}

class _WantButton extends StatefulWidget {
  final String shopId;
  final String? uid;
  const _WantButton({required this.shopId, required this.uid});

  @override
  State<_WantButton> createState() => _WantButtonState();
}

class _WantButtonState extends State<_WantButton> {
  final repo = sl<SocialRepository>();
  late final Stream<bool> _want$ = widget.uid == null
      ? Stream.value(false)
      : repo.watchWant(widget.uid!, widget.shopId);

  String? get uid => widget.uid;
  String get shopId => widget.shopId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _want$,
      builder: (context, snap) {
        final on = snap.data ?? false;
        return OverlayIconButton(
          icon: on ? Icons.where_to_vote_rounded : Icons.add_location_alt_outlined,
          tooltip: 'Mau ke sini',
          onPressed: () async {
            if (uid == null) {
              context.push(AppRouter.login);
              return;
            }
            final r = await repo.setWant(uid!, shopId, !on);
            if (context.mounted) {
              r.fold((f) => showAppSnack(context, f.message, error: true),
                  (_) => null);
            }
          },
        );
      },
    );
  }
}

/// Partner promos. Members open the rotating code; others see the paywall.
class _PromoStrip extends StatefulWidget {
  final CoffeeShop shop;
  const _PromoStrip({required this.shop});

  @override
  State<_PromoStrip> createState() => _PromoStripState();
}

class _PromoStripState extends State<_PromoStrip> {
  final repo = sl<CommerceRepository>();
  late final _promos$ = repo.watchShopPromos(widget.shop.id);
  String? _memberUid;
  Stream<Membership> _membership$ = Stream.value(Membership.none);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : null;
    if (uid != _memberUid) {
      _memberUid = uid;
      _membership$ =
          uid == null ? Stream.value(Membership.none) : repo.watchMembership(uid);
    }
    return StreamBuilder<List<Promo>>(
      stream: _promos$,
      builder: (context, snap) {
        final promos = snap.data ?? const <Promo>[];
        if (promos.isEmpty) return const SizedBox.shrink();
        return StreamBuilder<Membership>(
          stream: _membership$,
          builder: (context, m) {
            final member = m.data?.active == true;
            return Column(children: [
              for (final p in promos) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    if (uid == null) {
                      context.push(AppRouter.login);
                    } else if (p.memberOnly && !member) {
                      context.push(AppRouter.streetPass);
                    } else {
                      context.push(AppRouter.usePromo, extra: p);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x669FE444)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.confirmation_number_rounded,
                            color: AppColors.onPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              MonoText('PROMO DARI KEDAI',
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: AppColors.primary),
                              if (p.memberOnly) ...[
                                const SizedBox(width: 6),
                                const PassTag(),
                              ],
                            ]),
                            const SizedBox(height: 3),
                            Text(p.title,
                                style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
                            Text(
                                'Sisa kuota hari ini ${p.quotaLeft} · s/d ${p.endAt.day}/${p.endAt.month}',
                                style: AppTextStyles.meta.copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.primary),
                    ]),
                  ),
                ),
              ],
            ]);
          },
        );
      },
    );
  }
}

class _ShopDrops extends StatefulWidget {
  final String shopId;
  const _ShopDrops({required this.shopId});

  @override
  State<_ShopDrops> createState() => _ShopDropsState();
}

class _ShopDropsState extends State<_ShopDrops> {
  late final _drops$ = sl<SocialRepository>().watchShopDrops(widget.shopId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Drop>>(
      stream: _drops$,
      builder: (context, snap) {
        final drops = snap.data ?? const <Drop>[];
        if (snap.hasError && !snap.hasData) {
          return const InlineError('Drop di kedai ini gagal dimuat.');
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Skeleton(height: 220, radius: 16);
        }
        if (drops.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Belum ada Drop di sini. Jadi yang pertama dan dapat badge First Drop!',
                textAlign: TextAlign.center,
                style: AppTextStyles.meta),
          );
        }
        final a = [for (var i = 0; i < drops.length; i += 2) drops[i]];
        final b = [for (var i = 1; i < drops.length; i += 2) drops[i]];
        Widget col(List<Drop> ds, bool tallFirst) => Expanded(
              child: Column(children: [
                for (var i = 0; i < ds.length; i++) ...[
                  _masonryTile(ds[i], (i.isEven == tallFirst) ? 220 : 150),
                  const SizedBox(height: 10),
                ],
              ]),
            );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [col(a, true), const SizedBox(width: 10), col(b, false)],
        );
      },
    );
  }

  Widget _masonryTile(Drop d, double h) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: h,
          child: Stack(fit: StackFit.expand, children: [
            NetImage(d.coverUrl),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                decoration: BoxDecoration(
                  color: const Color(0xB30E0E0E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  UserAvatar(url: d.userPhotoUrl, name: d.userHandle, size: 20, radius: 6),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(d.userHandle,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.meta.copyWith(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.coffee_rounded, size: 12, color: AppColors.primary),
                  const SizedBox(width: 3),
                  Text(Fmt.compact(d.cheersCount),
                      style: AppTextStyles.meta.copyWith(
                          fontSize: 11, color: AppColors.textPrimary)),
                ]),
              ),
            ),
          ]),
        ),
      );
}

class _Regulars extends StatefulWidget {
  final String shopId;
  const _Regulars({required this.shopId});

  @override
  State<_Regulars> createState() => _RegularsState();
}

class _RegularsState extends State<_Regulars> {
  late var _future = sl<SocialRepository>().regulars(widget.shopId);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : null;
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) return const Skeleton(height: 200, radius: 16);
        final result = snap.data!;
        if (result.isLeft()) {
          return InlineError(
            result.fold((f) => f.message, (_) => ''),
            onRetry: () => setState(() =>
                _future = sl<SocialRepository>().regulars(widget.shopId)),
          );
        }
        final list = result.getOrElse(() => const <RegularEntry>[]);
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Belum ada Regulars bulan ini.',
                textAlign: TextAlign.center, style: AppTextStyles.meta),
          );
        }
        const medal = [Color(0xFFFFC107), Color(0xFFC9CED6), Color(0xFFD08B4E)];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paling sering check-in · reset tiap tanggal 1',
                style: AppTextStyles.meta.copyWith(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                for (var i = 0; i < list.length; i++)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: list[i].uid == uid ? AppColors.primarySoft : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i < 3 ? medal[i] : AppColors.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: Text('${i + 1}',
                            style: AppTextStyles.meta.copyWith(
                                fontWeight: FontWeight.w800,
                                color: i < 3 ? AppColors.onPrimary : AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      UserAvatar(url: list[i].photoUrl, name: list[i].handle),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(list[i].uid == uid ? 'Kamu' : list[i].handle,
                            style: AppTextStyles.body.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: list[i].uid == uid ? AppColors.primary : null)),
                      ),
                      const Icon(Icons.approval_rounded, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('${list[i].checkins}×',
                          style: AppTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
            ),
          ],
        );
      },
    );
  }
}
