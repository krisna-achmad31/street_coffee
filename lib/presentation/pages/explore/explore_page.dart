import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../blocs/explore/explore_bloc.dart';
import '../../blocs/location/location_bloc.dart';
import '../../widgets/cards/shop_cards.dart';
import '../../widgets/sheets/wa_confirm_sheet.dart';
import '../../widgets/ui/chips.dart';
import '../../widgets/ui/common.dart';
import '../../widgets/ui/location_problem.dart';
import '../../widgets/ui/osm_map.dart';
import 'filter_sheet.dart';

class ExplorePage extends StatefulWidget {
  final String? initialVibe;
  final bool startOnMap;
  const ExplorePage({super.key, this.initialVibe, this.startOnMap = false});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late ExploreFilters _filters =
      ExploreFilters(vibes: {if (widget.initialVibe != null) widget.initialVibe!});
  late bool _map = widget.startOnMap;
  final _search = TextEditingController();
  Timer? _debounce;
  CoffeeShop? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  @override
  void didUpdateWidget(covariant ExplorePage old) {
    super.didUpdateWidget(old);
    if (widget.initialVibe != old.initialVibe) {
      _filters = _filters.copyWith(
          vibes: {if (widget.initialVibe != null) widget.initialVibe!});
      _apply();
    }
  }

  void _apply() {
    final loc = context.read<LocationBloc>().state;
    if (loc is! LocationLoaded) return;
    final bloc = context.read<ExploreBloc>();
    if (_search.text.trim().isNotEmpty) {
      bloc.add(ExploreSearchChanged(
          query: _search.text.trim(), location: loc.location));
      return;
    }
    bloc.add(ExploreFilterChanged(
      vibe: _filters.vibes.isEmpty ? null : _filters.vibes.first,
      isOpen: _filters.openNow ? true : null,
      maxPrice: _filters.maxPrice,
    ));
    if (bloc.state is ExploreInitial) bloc.add(ExploreLoadShops(loc.location));
  }

  Future<void> _refresh() async {
    if (context.read<LocationBloc>().state is! LocationLoaded) return;
    final bloc = context.read<ExploreBloc>();
    _apply();
    await bloc.stream
        .firstWhere((s) => s is! ExploreLoading)
        .timeout(const Duration(seconds: 15), onTimeout: () => bloc.state);
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _apply);
  }

  Future<void> _openFilters() async {
    final res = await showFilterSheet(context, _filters);
    if (res != null) {
      setState(() => _filters = res);
      _apply();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationBloc, LocationState>(
      listener: (_, s) {
        if (s is LocationLoaded) {
          context.read<ExploreBloc>().add(ExploreLoadShops(s.location));
        }
      },
      child: Scaffold(
        body: BlocBuilder<ExploreBloc, ExploreState>(
          builder: (context, state) {
            final shops = state is ExploreLoaded
                ? _filters.applyLocal(state.shops)
                : const <CoffeeShop>[];
            return _map ? _buildMap(state, shops) : _buildList(state, shops);
          },
        ),
      ),
    );
  }

  Widget _controls({bool overMap = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 48,
            padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
            decoration: BoxDecoration(
              color: overMap ? const Color(0xF21E1E1E) : AppColors.input,
              borderRadius: BorderRadius.circular(12),
              boxShadow: overMap
                  ? const [BoxShadow(color: Color(0x80000000), blurRadius: 20)]
                  : null,
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Cari kedai, menu, atau vibe…',
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _openFilters,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _filters.count > 0
                          ? AppColors.primary
                          : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.tune_rounded,
                        size: 16,
                        color: _filters.count > 0
                            ? AppColors.onPrimary
                            : AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              AppFilterChip(
                label: 'Buka sekarang',
                active: _filters.openNow,
                showChevron: false,
                onTap: () {
                  setState(() =>
                      _filters = _filters.copyWith(openNow: !_filters.openNow));
                  _apply();
                },
              ),
              for (final v in _filters.vibes) ...[
                const SizedBox(width: 8),
                AppFilterChip(
                  label: v,
                  active: true,
                  onTap: () {
                    setState(() => _filters = _filters
                        .copyWith(vibes: {..._filters.vibes}..remove(v)));
                    _apply();
                  },
                ),
              ],
              const SizedBox(width: 8),
              AppFilterChip(
                label: _filters.maxPrice == null
                    ? 'Harga'
                    : '< ${(_filters.maxPrice! / 1000).round()}k',
                active: _filters.maxPrice != null,
                onTap: _openFilters,
              ),
              const SizedBox(width: 8),
              AppFilterChip(
                label: 'Rating 4+',
                active: _filters.minRating != null,
                onTap: () {
                  setState(() => _filters = _filters.copyWith(
                      minRating: _filters.minRating == null ? 4.0 : null,
                      clearRating: _filters.minRating != null));
                },
              ),
              const SizedBox(width: 8),
              AppFilterChip(
                label: _filters.facilities.isEmpty
                    ? 'Fasilitas'
                    : _filters.facilities.join(', '),
                active: _filters.facilities.isNotEmpty,
                onTap: _openFilters,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(ExploreState state, List<CoffeeShop> shops) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          ScreenHeader(
            title: 'Explore',
            trailing: _ViewToggle(map: false, onChanged: (m) => setState(() => _map = m)),
          ),
          _controls(),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state is ExploreLoaded ? '${shops.length} kedai ditemukan' : '',
                    style: AppTextStyles.meta.copyWith(fontSize: 13),
                  ),
                ),
                GestureDetector(
                  onTap: _openFilters,
                  child: Row(
                    children: [
                      const Icon(Icons.swap_vert_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(_filters.sort.label,
                          style: AppTextStyles.badge.copyWith(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _listBody(state, shops)),
        ],
      ),
    );
  }

  Widget _listBody(ExploreState state, List<CoffeeShop> shops) {
    final loc = context.watch<LocationBloc>().state;
    if (loc is LocationError && state is ExploreInitial) {
      return SingleChildScrollView(child: LocationProblemView(error: loc));
    }
    if (state is ExploreLoading || state is ExploreInitial) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const Skeleton(height: 116, radius: 16),
      );
    }
    if (state is ExploreError) {
      return StateView(
        icon: Icons.wifi_off_rounded,
        title: 'Kedai gagal dimuat',
        message: state.message,
        danger: true,
        actionLabel: 'Coba lagi',
        actionIcon: Icons.refresh_rounded,
        onAction: _apply,
      );
    }
    if (state is ExploreEmpty || shops.isEmpty) {
      return StateView(
        icon: Icons.coffee_outlined,
        title: 'Belum ada kedai yang cocok',
        message:
            'Coba longgarkan filter harga atau pilih vibe lain. Kedai baru ditambahkan tiap minggu.',
        actionLabel: 'Reset filter',
        actionIcon: Icons.restart_alt_rounded,
        onAction: () {
          setState(() => _filters = const ExploreFilters());
          _search.clear();
          _apply();
        },
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
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
  }

  Widget _buildMap(ExploreState state, List<CoffeeShop> shops) {
    final loc = context.watch<LocationBloc>().state;
    final user = loc is LocationLoaded
        ? LatLng(loc.location.latitude, loc.location.longitude)
        : null;
    final pinned = shops.where((s) => s.hasLocation).toList();
    // Far from every shop (e.g. travelling): frame the shops, not an empty
    // map around the user.
    final nearUser = user != null && pinned.any((s) => (s.distanceKm ?? 1e9) <= 30);
    final fitShops = pinned.isNotEmpty && !nearUser;
    // The previously tapped shop may have been filtered out since.
    final selected = pinned.contains(_selected)
        ? _selected
        : (pinned.isEmpty ? null : pinned.first);
    return Stack(
      children: [
        FlutterMap(
          // Re-frame when the result set changes (filters, new location).
          key: ValueKey('$fitShops-${pinned.map((s) => s.id).join(',')}'),
          options: MapOptions(
            initialCenter: user ?? const LatLng(-6.2441, 106.7991),
            initialZoom: 15,
            initialCameraFit: fitShops
                ? CameraFit.coordinates(
                    coordinates: [
                      for (final s in pinned) LatLng(s.latitude, s.longitude)
                    ],
                    padding: const EdgeInsets.fromLTRB(56, 250, 56, 380),
                    maxZoom: 16,
                  )
                : null,
            onTap: (_, __) => setState(() => _selected = null),
          ),
          children: [
            osmTileLayer(),
            MarkerLayer(markers: [
              if (user != null)
              Marker(
                point: user,
                width: 56,
                height: 56,
                child: Container(
                  decoration: const BoxDecoration(
                      color: Color(0x339FE444), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 3),
                    ),
                  ),
                ),
              ),
              for (final s in pinned)
                Marker(
                  point: LatLng(s.latitude, s.longitude),
                  width: 88,
                  height: 36,
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = s),
                    child: _Pin(shop: s, selected: s.id == selected?.id),
                  ),
                ),
            ]),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 96 +
              MediaQuery.of(context).padding.bottom +
              (selected != null ? 128 : 8),
          child: const OsmAttribution(),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Row(
                  children: [
                    const Spacer(),
                    _ViewToggle(
                        map: true, onChanged: (m) => setState(() => _map = m)),
                  ],
                ),
              ),
              _controls(overMap: true),
            ],
          ),
        ),
        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 96 + MediaQuery.of(context).padding.bottom,
            child: ShopCard(
              shop: selected,
              elevated: true,
              onTap: () => context.push('${AppRouter.detail}/${selected.id}'),
              onWhatsApp: selected.canOrderViaWa
                  ? () => showWaConfirmSheet(context, shop: selected)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  final CoffeeShop shop;
  final bool selected;
  const _Pin({required this.shop, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? AppColors.onPrimary : AppColors.divider,
              width: selected ? 2 : 1),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 12)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? AppColors.onPrimary : AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                  shop.isPartner
                      ? Icons.confirmation_number_rounded
                      : Icons.coffee_rounded,
                  size: 12,
                  color: AppColors.primary),
            ),
            const SizedBox(width: 5),
            Text('★ ${shop.rating.toStringAsFixed(1)}',
                style: AppTextStyles.meta.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.onPrimary : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final bool map;
  final ValueChanged<bool> onChanged;
  const _ViewToggle({required this.map, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget item(bool isMap, IconData icon) => GestureDetector(
          onTap: () => onChanged(isMap),
          child: Container(
            width: 36,
            height: 32,
            decoration: BoxDecoration(
              color: map == isMap ? AppColors.surfaceAlt : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                size: 17,
                color: map == isMap ? AppColors.primary : AppColors.textMuted),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        item(false, Icons.view_list_rounded),
        const SizedBox(width: 2),
        item(true, Icons.map_rounded),
      ]),
    );
  }
}
