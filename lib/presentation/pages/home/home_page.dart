import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/explore/explore_bloc.dart';
import '../../blocs/location/location_bloc.dart';
import '../../widgets/coffee_card/featured_card.dart';
import '../../widgets/coffee_card/nearby_card.dart';
import '../../widgets/common/vibe_chip.dart';
import '../../widgets/common/bottom_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTab = 0;

  static const _vibes = [
    ('☕', 'Nongkrong\nSkena'),
    ('💬', 'Deep Talk'),
    ('🫗', 'Manual Brew'),
    ('💰', 'Kopi Hemat'),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final locationState = context.read<LocationBloc>().state;
    if (locationState is LocationLoaded) {
      context.read<ExploreBloc>().add(ExploreLoadShops(locationState.location));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildHomeContent(),
          _buildMapContent(),
          _buildProfileContent(), // ← tab ke-3
        ],
      ),
      floatingActionButton: _currentTab == 0
          ? BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is AuthAuthenticated && state.user.isAdmin) {
                  return FloatingActionButton(
                    onPressed: () => context.push(AppRouter.adminAddShop),
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.add, color: AppColors.bgDark),
                  );
                }
                return const SizedBox.shrink();
              },
            )
          : null,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentTab,
        onTap: (index) {
          setState(() => _currentTab = index);
          if (index == 0) _loadData();
        },
      ),
    );
  }

  // ─── Tab 0: Home ──────────────────────────────────────────────────────────

  Widget _buildHomeContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLocationHeader(),
                  const SizedBox(height: 20),
                  _buildFeaturedSection(),
                  const SizedBox(height: 20),
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                  _buildVibeCategories(),
                  const SizedBox(height: 20),
                  Text('Kedai Terdekat Baru', style: AppTextStyles.headingMedium),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
        BlocBuilder<ExploreBloc, ExploreState>(
          builder: (context, state) {
            if (state is ExploreLoading) {
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const _ShimmerCard(),
                  childCount: 4,
                ),
              );
            }
            if (state is ExploreLoaded) {
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final shop = state.shops[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: NearbyCard(
                          shop: shop,
                          onTap: () => context.push('${AppRouter.detail}/${shop.id}'),
                          onWhatsAppTap: () => context.push('${AppRouter.detail}/${shop.id}'),
                        ),
                      );
                    },
                    childCount: state.shops.take(6).length,
                  ),
                ),
              );
            }
            if (state is ExploreEmpty) {
              return SliverToBoxAdapter(child: _buildEmptyState(state.message));
            }
            if (state is ExploreError) {
              return SliverToBoxAdapter(child: _buildErrorState(state.message));
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
        ),
      ],
    );
  }

  Widget _buildLocationHeader() {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, state) {
        final locationText = state is LocationLoaded ? state.location.displayName : 'Mencari lokasi...';

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mencari dekat:', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => context.push(AppRouter.pickLocation),
                    child: Row(
                      children: [
                        Text(locationText, style: AppTextStyles.headingSmall),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textPrimary, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.notifications_none_rounded, color: AppColors.textSecondary, size: 22),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Featured Spots', style: AppTextStyles.headingMedium),
        const SizedBox(height: 12),
        BlocBuilder<ExploreBloc, ExploreState>(
          builder: (context, state) {
            if (state is ExploreLoaded) {
              final featured = state.shops.where((s) => s.isFeatured).take(5).toList();
              if (featured.isEmpty) {
                return const SizedBox(
                    height: 180,
                    child: Center(
                      child: Icon(Icons.coffee_outlined, size: 40, color: AppColors.textMuted),
                    ));
              }
              return SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: featured.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => FeaturedCard(
                    shop: featured[index],
                    onTap: () => context.push('${AppRouter.detail}/${featured[index].id}'),
                  ),
                ),
              );
            }
            return SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => const _ShimmerFeatured(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => context.push(AppRouter.explore),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
            Text('Cari kedai atau vibe...', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildVibeCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kategori Suasana', style: AppTextStyles.headingMedium),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _vibes.map((vibe) {
            return VibeChip(
              emoji: vibe.$1,
              label: vibe.$2,
              onTap: () => context.push(
                AppRouter.explore,
                extra: {'vibe': vibe.$2.replaceAll('\n', ' ')},
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Tab 1: Map ───────────────────────────────────────────────────────────

  Widget _buildMapContent() {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, locationState) {
        final center = locationState is LocationLoaded
            ? LatLng(locationState.location.latitude, locationState.location.longitude)
            : const LatLng(-6.2088, 106.8456);

        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.streetcoffee.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bgDark, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.coffee_rounded, color: AppColors.bgDark, size: 20),
                      ),
                    ),
                    ...() {
                      final exploreState = context.read<ExploreBloc>().state;
                      if (exploreState is ExploreLoaded) {
                        return exploreState.shops
                            .map((shop) => Marker(
                                  point: LatLng(shop.latitude, shop.longitude),
                                  width: 40,
                                  height: 40,
                                  child: GestureDetector(
                                    onTap: () => context.push('${AppRouter.detail}/${shop.id}'),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.bgCard,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.primary, width: 2),
                                      ),
                                      child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 18),
                                    ),
                                  ),
                                ))
                            .toList();
                      }
                      return <Marker>[];
                    }(),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildMapBottomSheet(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapBottomSheet() {
    return BlocBuilder<ExploreBloc, ExploreState>(
      builder: (context, state) {
        if (state is! ExploreLoaded || state.shops.isEmpty) {
          return const SizedBox.shrink();
        }
        final shop = state.shops.first;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  shop.imageUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 72,
                    height: 72,
                    color: AppColors.bgCardAlt,
                    child: const Icon(Icons.coffee, color: AppColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.name, style: AppTextStyles.headingSmall),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.star, size: 14),
                        const SizedBox(width: 2),
                        Text(shop.rating.toStringAsFixed(1), style: AppTextStyles.bodySmall),
                        const SizedBox(width: 8),
                        Expanded(child: Text(shop.distanceText, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis,)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: shop.categories
                          .take(3)
                          .map((c) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.bgCardAlt,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(c, style: AppTextStyles.caption),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => context.push('${AppRouter.detail}/${shop.id}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Detail', style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Tab 2: Profile ───────────────────────────────────────────────────────

  Widget _buildProfileContent() {
    return SafeArea(
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return _buildLoggedInProfile(state);
          }
          return _buildGuestProfile();
        },
      ),
    );
  }

  Widget _buildLoggedInProfile(AuthAuthenticated state) {
    final user = state.user;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        // Avatar
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                backgroundColor: AppColors.bgCard,
                child: user.photoUrl == null
                    ? Text(
                        user.displayName[0].toUpperCase(),
                        style: AppTextStyles.headingLarge,
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              Text(user.displayName, style: AppTextStyles.headingMedium),
              const SizedBox(height: 4),
              Text(user.email, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              if (user.isAdmin) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Text('⚡ Admin', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Admin section
        if (user.isAdmin) ...[
          _sectionLabel('Admin'),
          _menuTile(
            icon: Icons.add_business_rounded,
            label: 'Tambah Kedai Baru',
            onTap: () => context.push(AppRouter.adminAddShop),
          ),
          const SizedBox(height: 8),
          _menuTile(
            icon: Icons.store_rounded,
            label: 'Kelola Semua Kedai',
            onTap: () => context.push(AppRouter.explore),
          ),
          const SizedBox(height: 20),
        ],

        // General section
        _sectionLabel('Umum'),
        _menuTile(
          icon: Icons.location_on_rounded,
          label: 'Ubah Lokasi',
          onTap: () => context.push(AppRouter.pickLocation),
        ),
        const SizedBox(height: 32),

        // Logout
        GestureDetector(
          onTap: () => context.read<AuthBloc>().add(AuthSignOut()),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.closed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.closed.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout_rounded, color: AppColors.closed, size: 20),
                const SizedBox(width: 8),
                Text('Logout', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.closed, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestProfile() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline_rounded, size: 44, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          Text('Belum Login', style: AppTextStyles.headingMedium),
          const SizedBox(height: 8),
          Text(
            'Login untuk kasih review, order, dan akses fitur lengkap',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => context.push(AppRouter.login),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF4285F4))),
                  const SizedBox(width: 10),
                  Text('Login dengan Google', style: AppTextStyles.button),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  // ─── State widgets ────────────────────────────────────────────────────────

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            const Icon(Icons.coffee_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(message, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(message, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Coba Lagi', style: AppTextStyles.button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _ShimmerFeatured extends StatelessWidget {
  const _ShimmerFeatured();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
