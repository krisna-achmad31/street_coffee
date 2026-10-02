import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../../domain/entities/commerce.dart';
import '../../../domain/entities/social.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../../injection_container.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/chips.dart';
import '../../widgets/ui/common.dart';
import '../../widgets/ui/receipt.dart';
import '../auth/login_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => state is AuthAuthenticated
              ? _MemberProfile(key: ValueKey(state.user.uid), user: state.user)
              : const _GuestProfile(),
        ),
      ),
    );
  }
}

class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: [
        Text('Profil', style: AppTextStyles.title),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x409FE444)),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x339FE444), AppColors.surface],
              stops: [0, 0.7],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_outline_rounded,
                    size: 30, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              Text('Belum masuk', style: AppTextStyles.section.copyWith(fontSize: 20)),
              const SizedBox(height: 6),
              Text(
                  'Masuk untuk kasih review, kumpulkan stempel paspor, dan nge-Drop kedai favoritmu.',
                  style: AppTextStyles.body.copyWith(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              GoogleSignInButton(
                label: 'Masuk dengan Google',
                onTap: () => context.read<AuthBloc>().add(AuthSignInGoogle()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const OverlineLabel('Umum'),
        const SizedBox(height: 8),
        MenuTile(
          icon: Icons.location_on_outlined,
          title: 'Ubah lokasi',
          onTap: () => context.push(AppRouter.pickLocation),
        ),
        const SizedBox(height: 8),
        MenuTile(
          icon: Icons.storefront_outlined,
          title: 'Punya kedai kopi?',
          subtitle: 'Gabung Kedai Pro',
          onTap: () => context.push(AppRouter.kedaiPro),
        ),
        const SizedBox(height: 8),
        const MenuTile(
          icon: Icons.info_outline_rounded,
          title: 'Tentang Street Coffee',
          subtitle: 'Versi 2.0.0',
        ),
      ],
    );
  }
}

enum _ProfileTab { stamps, drops, wants }

class _MemberProfile extends StatefulWidget {
  final AppUser user;
  const _MemberProfile({super.key, required this.user});

  @override
  State<_MemberProfile> createState() => _MemberProfileState();
}

class _MemberProfileState extends State<_MemberProfile> {
  final _social = sl<SocialRepository>();
  final _commerce = sl<CommerceRepository>();
  _ProfileTab _tab = _ProfileTab.stamps;

  late final _profile$ = _social.watchProfile(widget.user.uid);
  late final _stamps$ = _social.watchStamps(widget.user.uid);
  late final _drops$ = _social.watchUserDrops(widget.user.uid);
  late final _owned$ = _commerce.watchOwnedShops(widget.user.uid);
  late final _membership$ = _commerce.watchMembership(widget.user.uid);

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return StreamBuilder<UserProfile?>(
      stream: _profile$,
      builder: (context, p) {
        final profile = p.data ??
            UserProfile(uid: u.uid, handle: u.displayName, displayName: u.displayName, photoUrl: u.photoUrl);
        return StreamBuilder<List<Stamp>>(
          stream: _stamps$,
          builder: (context, s) {
            final stamps = s.data ?? const <Stamp>[];
            return StreamBuilder<List<Drop>>(
              stream: _drops$,
              builder: (context, d) {
                final drops = d.data ?? const <Drop>[];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  children: [
                    _header(profile),
                    const SizedBox(height: 20),
                    _PassportCard(profile: profile, stamps: stamps.length),
                    const SizedBox(height: 16),
                    _statsStrip(profile, stamps),
                    if (profile.bio.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(profile.bio,
                          style: AppTextStyles.body
                              .copyWith(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: 16),
                    _actions(profile, stamps.length),
                    const SizedBox(height: 24),
                    _badges(drops, stamps.length),
                    const SizedBox(height: 24),
                    Segmented<_ProfileTab>(
                      items: const [
                        (_ProfileTab.stamps, 'Stempel', Icons.approval_rounded),
                        (_ProfileTab.drops, 'Drops', Icons.confirmation_number_outlined),
                        (_ProfileTab.wants, 'Mau ke sini', Icons.add_location_alt_outlined),
                      ],
                      value: _tab,
                      onChanged: (t) => setState(() => _tab = t),
                    ),
                    const SizedBox(height: 16),
                    switch (_tab) {
                      _ProfileTab.stamps => _StampPage(stamps: stamps),
                      _ProfileTab.drops => _DropsGrid(drops: drops),
                      _ProfileTab.wants => _Wants(uid: u.uid),
                    },
                    const SizedBox(height: 28),
                    _ownerSection(),
                    if (u.isAdmin) ..._adminSection(),
                    const SizedBox(height: 24),
                    const OverlineLabel('Umum'),
                    const SizedBox(height: 8),
                    MenuTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifikasi',
                      onTap: () => context.push(AppRouter.notifications),
                    ),
                    const SizedBox(height: 8),
                    MenuTile(
                      icon: Icons.location_on_outlined,
                      title: 'Ubah lokasi',
                      onTap: () => context.push(AppRouter.pickLocation),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Keluar',
                      icon: Icons.logout_rounded,
                      background: AppColors.closedSoft,
                      foreground: AppColors.closed,
                      onPressed: () => context.read<AuthBloc>().add(AuthSignOut()),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _header(UserProfile p) => Row(
        children: [
          Flexible(
            child: Text(p.handle,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.section.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          if (p.isPass) ...[const SizedBox(width: 6), const PassTag()],
          const Spacer(),
          OverlayIconButton(
            icon: Icons.notifications_none_rounded,
            background: AppColors.surface,
            tooltip: 'Notifikasi',
            onPressed: () => context.push(AppRouter.notifications),
          ),
        ],
      );

  Widget _statsStrip(UserProfile p, List<Stamp> stamps) {
    final areas = stamps.map((s) => s.area).whereType<String>().toSet().length;
    final cells = [
      (Fmt.compact(p.dropsCount), 'DROPS'),
      (Fmt.compact(p.followersCount), 'PENGIKUT'),
      (Fmt.compact(p.followingCount), 'MENGIKUTI'),
      ('${areas == 0 ? p.areasCount : areas}', 'AREA'),
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const VerticalDivider(width: 1, color: AppColors.divider),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  Text(cells[i].$1, style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
                  MonoText(cells[i].$2, size: 9, color: AppColors.textMuted),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _actions(UserProfile p, int stamps) {
    final level = PassportLevel.of(stamps);
    return StreamBuilder<Membership>(
      stream: _membership$,
      builder: (context, m) => Row(children: [
        Expanded(
          child: SecondaryButton(
            label: m.data?.active == true ? 'Street Pass aktif' : 'Street Pass',
            icon: Icons.bolt_rounded,
            height: 44,
            onPressed: () => context.push(AppRouter.streetPass),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PrimaryButton(
            label: 'Bagikan',
            icon: Icons.ios_share_rounded,
            height: 44,
            onPressed: () => SharePlus.instance.share(ShareParams(
                text:
                    'Paspor kopiku: $stamps stempel · Lv.${level.level} ${level.name} ☕ — @${p.handle} di Street Coffee')),
          ),
        ),
      ]),
    );
  }

  Widget _badges(List<Drop> drops, int stamps) {
    final badges = _social.computeBadges(drops, stamps);
    const icons = {
      'night_owl': Icons.nightlight_round,
      'manual_brew': Icons.science_outlined,
      'first_drop': Icons.flag_rounded,
      'kopi_hemat': Icons.savings_outlined,
      'skena_legend': Icons.workspace_premium_rounded,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
            title: 'Badge',
            action: '${badges.where((b) => b.unlocked).length} dari ${badges.length}'),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (_, i) => Tooltip(
              message: badges[i].description,
              child: AchievementMedal(
                icon: icons[badges[i].id] ?? Icons.star_rounded,
                label: badges[i].name,
                unlocked: badges[i].unlocked,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ownerSection() => StreamBuilder<List<CoffeeShop>>(
        stream: _owned$,
        builder: (context, snap) {
          final shops = snap.data ?? const <CoffeeShop>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OverlineLabel('Kedai saya'),
              const SizedBox(height: 8),
              if (shops.isEmpty)
                MenuTile(
                  icon: Icons.storefront_outlined,
                  title: 'Punya kedai kopi?',
                  subtitle: 'Gabung Kedai Pro — gratis 3 bulan',
                  onTap: () => context.push(AppRouter.kedaiPro),
                ),
              for (final s in shops) ...[
                MenuTile(
                  icon: Icons.insights_rounded,
                  title: s.displayName,
                  subtitle: s.isPro ? 'Dashboard Kedai Pro' : 'Dashboard (Basic)',
                  highlighted: true,
                  onTap: () => context.push('${AppRouter.kedaiProDashboard}/${s.id}'),
                ),
                const SizedBox(height: 8),
                MenuTile(
                  icon: Icons.point_of_sale_rounded,
                  title: 'Mode kasir',
                  subtitle: 'Validasi kode promo member',
                  onTap: () => context.push('${AppRouter.cashier}/${s.id}'),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      );

  List<Widget> _adminSection() => [
        const SizedBox(height: 24),
        const OverlineLabel('Admin'),
        const SizedBox(height: 8),
        MenuTile(
          icon: Icons.add_business_rounded,
          title: 'Tambah kedai baru',
          highlighted: true,
          trailing: Icons.add_rounded,
          onTap: () => context.push(AppRouter.adminAddShop),
        ),
        const SizedBox(height: 8),
        MenuTile(
          icon: Icons.view_list_rounded,
          title: 'Kelola semua kedai',
          onTap: () => context.go(AppRouter.explore),
        ),
      ];
}

class _PassportCard extends StatelessWidget {
  final UserProfile profile;
  final int stamps;
  const _PassportCard({required this.profile, required this.stamps});

  @override
  Widget build(BuildContext context) {
    final level = PassportLevel.of(stamps);
    final next = PassportLevel.next(stamps);
    final progress = next == null
        ? 1.0
        : (stamps - level.minStamps) / (next.minStamps - level.minStamps);
    final surname = profile.displayName.split(' ').last.toUpperCase();
    final given = profile.displayName.split(' ').first.toUpperCase();
    final head = 'P<SC<$surname<<$given'.padRight(28, '<');
    final mrz =
        '$head${stamps.toString().padLeft(3, '0')}<<${level.level.toString().padLeft(2, '0')}';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x559FE444)),
      ),
      child: Column(children: [
        Container(
          color: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Row(children: [
            MonoText('REPUBLIK NGOPI',
                size: 10, weight: FontWeight.w700, color: AppColors.onPrimary, letterSpacing: 1.5),
            Spacer(),
            Icon(Icons.approval_rounded, size: 13, color: AppColors.onPrimary),
            SizedBox(width: 5),
            MonoText('COFFEE PASSPORT',
                size: 10, weight: FontWeight.w700, color: AppColors.onPrimary, letterSpacing: 1),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            UserAvatar(url: profile.photoUrl, name: profile.displayName, size: 92, radius: 12),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field('NAMA', profile.displayName, display: true),
                  _field('NO. PASPOR', profile.passportNo),
                  _field('LEVEL',
                      '${level.level.toString().padLeft(2, '0')} · ${level.name.toUpperCase()}',
                      color: AppColors.primary),
                ],
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: const Color(0x14FFFFFF),
                ),
              ),
              const SizedBox(height: 6),
              MonoText(
                next == null
                    ? '$stamps STEMPEL · LEVEL TERTINGGI'
                    : '$stamps/${next.minStamps} STEMPEL → LV.${next.level.toString().padLeft(2, '0')} ${next.name.toUpperCase()}',
                size: 9,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          color: AppColors.surfaceAlt,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: MonoText(mrz,
              size: 10, color: AppColors.textMuted, letterSpacing: 0.6),
        ),
      ]),
    );
  }

  Widget _field(String k, String v, {bool display = false, Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoText(k, size: 9, color: AppColors.textMuted, letterSpacing: 0.8),
            Text(v,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: display
                    ? AppTextStyles.cardTitle
                    : AppTextStyles.mono.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color ?? AppColors.textPrimary)),
          ],
        ),
      );
}

class _StampPage extends StatelessWidget {
  final List<Stamp> stamps;
  const _StampPage({required this.stamps});

  @override
  Widget build(BuildContext context) {
    const angles = [-0.14, 0.1, -0.07, 0.17, -0.2, 0.07, -0.1, 0.12];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1C16), Color(0xFF141414)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const MonoText('HAL. 01 · JAKARTA', size: 10, color: AppColors.textMuted),
            const Spacer(),
            MonoText('${stamps.length} STEMPEL',
                size: 10, weight: FontWeight.w700, color: AppColors.primary),
          ]),
          const SizedBox(height: 18),
          if (stamps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                  'Halaman ini masih kosong. Nge-Drop di kedai pertamamu buat dapat stempel.',
                  style: AppTextStyles.meta),
            )
          else
            Wrap(
              spacing: 4,
              runSpacing: 18,
              children: [
                for (var i = 0; i < stamps.length; i++)
                  PassportStamp(
                    imageUrl: stamps[i].imageUrl,
                    name: stamps[i].shopName,
                    date: Fmt.ddmm(stamps[i].firstVisit),
                    angle: angles[i % angles.length],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DropsGrid extends StatelessWidget {
  final List<Drop> drops;
  const _DropsGrid({required this.drops});

  @override
  Widget build(BuildContext context) {
    if (drops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('Belum ada Drop.', textAlign: TextAlign.center, style: AppTextStyles.meta),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: drops.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.8),
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(fit: StackFit.expand, children: [
          NetImage(drops[i].coverUrl),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xCC0E0E0E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: MonoText(drops[i].shopName.toUpperCase(),
                  size: 9, weight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Wants extends StatefulWidget {
  final String uid;
  const _Wants({required this.uid});

  @override
  State<_Wants> createState() => _WantsState();
}

class _WantsState extends State<_Wants> {
  late var _wants$ = sl<SocialRepository>().watchWantedShops(widget.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CoffeeShop>>(
      stream: _wants$,
      builder: (context, snap) {
        if (snap.hasError && !snap.hasData) {
          return InlineError(
            'Daftar "Mau ke sini" gagal dimuat.',
            onRetry: () => setState(() =>
                _wants$ = sl<SocialRepository>().watchWantedShops(widget.uid)),
          );
        }
        if (!snap.hasData) return const Skeleton(height: 120, radius: 16);
        final shops = snap.data!;
        if (shops.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Tandai kedai dengan 📍 "Mau ke sini" supaya muncul di sini.',
                textAlign: TextAlign.center, style: AppTextStyles.meta),
          );
        }
        return Column(children: [
          for (final shop in shops)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MenuTile(
                icon: Icons.where_to_vote_rounded,
                title: shop.displayName,
                subtitle: shop.address.isEmpty ? null : shop.address,
                onTap: () => context.push('${AppRouter.detail}/${shop.id}'),
              ),
            ),
        ]);
      },
    );
  }
}
