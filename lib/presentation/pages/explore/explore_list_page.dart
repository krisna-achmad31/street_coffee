import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../blocs/explore/explore_bloc.dart';
import '../../blocs/location/location_bloc.dart';
import '../../widgets/coffee_card/nearby_card.dart';
import '../../widgets/common/bottom_nav_bar.dart';

class ExploreListPage extends StatefulWidget {
  final String? initialVibe;
  const ExploreListPage({super.key, this.initialVibe});

  @override
  State<ExploreListPage> createState() => _ExploreListPageState();
}

class _ExploreListPageState extends State<ExploreListPage> {
  final _searchController = TextEditingController();
  String? _activeVibe;
  bool? _isOpenFilter;

  static const _vibes = [
    'Nongkrong Skena',
    'Deep Talk',
    'Manual Brew',
    'Kopi Hemat',
  ];

  @override
  void initState() {
    super.initState();
    _activeVibe = widget.initialVibe;
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyFilters());
  }

  void _applyFilters() {
    final locationState = context.read<LocationBloc>().state;
    if (locationState is LocationLoaded) {
      context.read<ExploreBloc>().add(
            ExploreLoadShops(locationState.location),
          );
      if (_activeVibe != null || _isOpenFilter != null) {
        context.read<ExploreBloc>().add(
              ExploreFilterChanged(
                vibe: _activeVibe,
                isOpen: _isOpenFilter,
              ),
            );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Explore List', style: AppTextStyles.headingMedium),
      ),
      body: Column(
        children: [
          // Search + Filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter chips
                Row(
                  children: [
                    Text('Filter:', style: AppTextStyles.bodySmall),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Harga',
                      isActive: false,
                      onTap: _showPriceFilter,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Vibe',
                      isActive: _activeVibe != null,
                      onTap: _showVibeFilter,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Buka/Tutup',
                      isActive: _isOpenFilter != null,
                      onTap: () {
                        setState(() {
                          _isOpenFilter =
                              _isOpenFilter == true ? null : true;
                        });
                        _applyFilters();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Location indicator
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 4),
                    BlocBuilder<LocationBloc, LocationState>(
                      builder: (context, state) => Text(
                        state is LocationLoaded
                            ? 'Terdekat dari ${state.location.displayName}'
                            : 'Terdekat Kamu',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Shop list
          Expanded(
            child: BlocBuilder<ExploreBloc, ExploreState>(
              builder: (context, state) {
                if (state is ExploreLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  );
                }
                if (state is ExploreLoaded) {
                  return RefreshIndicator(
                    color: AppColors.primary,
                    backgroundColor: AppColors.bgCard,
                    onRefresh: () async => _applyFilters(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: state.shops.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final shop = state.shops[index];
                        return NearbyCard(
                          shop: shop,
                          onTap: () => context.push(
                            '${AppRouter.detail}/${shop.id}',
                          ),
                          onWhatsAppTap: () => context.push(
                            '${AppRouter.detail}/${shop.id}',
                          ),
                        );
                      },
                    ),
                  );
                }
                if (state is ExploreEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.coffee_outlined,
                            size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          state.message,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }
                if (state is ExploreError) {
                  return Center(
                    child: Text(
                      state.message,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) context.go(AppRouter.home);
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isActive ? AppColors.bgDark : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _showVibeFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pilih Vibe', style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            ..._vibes.map((vibe) => ListTile(
                  title: Text(vibe, style: AppTextStyles.bodyMedium),
                  trailing: _activeVibe == vibe
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _activeVibe = _activeVibe == vibe ? null : vibe;
                    });
                    Navigator.pop(ctx);
                    _applyFilters();
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showPriceFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maksimal Harga', style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            ...['Semua Harga', 'Di bawah Rp 15k', 'Di bawah Rp 25k', 'Di bawah Rp 50k']
                .map((label) => ListTile(
                      title: Text(label, style: AppTextStyles.bodyMedium),
                      onTap: () => Navigator.pop(ctx),
                    )),
          ],
        ),
      ),
    );
  }
}
