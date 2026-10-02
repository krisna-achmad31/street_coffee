import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/chips.dart';

enum ExploreSort {
  nearest('Terdekat'),
  rating('Rating'),
  cheapest('Termurah');

  final String label;
  const ExploreSort(this.label);
}

/// Server-side filters (vibe, open, max price) go through ExploreBloc;
/// sort, rating and facilities are applied locally.
class ExploreFilters {
  final ExploreSort sort;
  final int? maxPrice;
  final Set<String> vibes;
  final Set<String> facilities;
  final bool openNow;
  final double? minRating;

  const ExploreFilters({
    this.sort = ExploreSort.nearest,
    this.maxPrice,
    this.vibes = const {},
    this.facilities = const {},
    this.openNow = false,
    this.minRating,
  });

  int get count =>
      (maxPrice != null ? 1 : 0) +
      vibes.length +
      facilities.length +
      (openNow ? 1 : 0) +
      (minRating != null ? 1 : 0);

  ExploreFilters copyWith({
    ExploreSort? sort,
    int? maxPrice,
    bool clearPrice = false,
    Set<String>? vibes,
    Set<String>? facilities,
    bool? openNow,
    double? minRating,
    bool clearRating = false,
  }) =>
      ExploreFilters(
        sort: sort ?? this.sort,
        maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
        vibes: vibes ?? this.vibes,
        facilities: facilities ?? this.facilities,
        openNow: openNow ?? this.openNow,
        minRating: clearRating ? null : (minRating ?? this.minRating),
      );

  List<CoffeeShop> applyLocal(List<CoffeeShop> shops) {
    final out = shops.where((s) {
      if (minRating != null && s.rating < minRating!) return false;
      if (facilities.isNotEmpty && !facilities.every(s.facilities.contains)) {
        return false;
      }
      return true;
    }).toList();
    switch (sort) {
      case ExploreSort.nearest:
        out.sort((a, b) =>
            (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9));
      case ExploreSort.rating:
        out.sort((a, b) => b.rating.compareTo(a.rating));
      case ExploreSort.cheapest:
        out.sort((a, b) => a.minPrice.compareTo(b.minPrice));
    }
    return out;
  }
}

Future<ExploreFilters?> showFilterSheet(
    BuildContext context, ExploreFilters current) {
  return showModalBottomSheet<ExploreFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  final ExploreFilters initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ExploreFilters f = widget.initial;

  static const _prices = [(null, 'Semua'), (15000, '< 15k'), (25000, '< 25k'), (50000, '< 50k')];
  static const _vibes = [
    '☕ Nongkrong Skena',
    '💬 Deep Talk',
    '🫗 Manual Brew',
    '💰 Kopi Hemat',
    '🌿 Santai',
    '💻 Kerja',
  ];
  static const _facilities = ['WiFi', 'Colokan', 'Outdoor', 'Parkir', 'AC', 'Musik'];

  Widget _group(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppTextStyles.meta.copyWith(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _chip(String label, bool active, VoidCallback onTap) =>
      AppFilterChip(label: label, active: active, showChevron: false, onTap: onTap);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Filter',
                        style: AppTextStyles.section.copyWith(fontSize: 20))),
                GestureDetector(
                  onTap: () => setState(() => f = const ExploreFilters()),
                  child: Text('Reset',
                      style: AppTextStyles.badge.copyWith(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _group(
              'Urutkan',
              Segmented<ExploreSort>(
                items: [for (final s in ExploreSort.values) (s, s.label, null)],
                value: f.sort,
                onChanged: (s) => setState(() => f = f.copyWith(sort: s)),
              ),
            ),
            _group(
              'Harga per orang',
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (v, l) in _prices)
                  _chip(l, f.maxPrice == v,
                      () => setState(() => f = f.copyWith(maxPrice: v, clearPrice: v == null))),
              ]),
            ),
            _group(
              'Vibe',
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final v in _vibes)
                  Builder(builder: (_) {
                    final name = v.substring(v.indexOf(' ') + 1);
                    final on = f.vibes.contains(name);
                    // One vibe at a time: Firestore can't OR array-contains.
                    return _chip(v, on,
                        () => setState(() => f = f.copyWith(vibes: on ? {} : {name})));
                  }),
              ]),
            ),
            _group(
              'Fasilitas',
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final x in _facilities)
                  _chip(x, f.facilities.contains(x), () {
                    final s = {...f.facilities};
                    s.contains(x) ? s.remove(x) : s.add(x);
                    setState(() => f = f.copyWith(facilities: s));
                  }),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Buka sekarang',
                            style: AppTextStyles.body
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text('Sembunyikan kedai yang tutup',
                            style: AppTextStyles.meta
                                .copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Switch(
                    value: f.openNow,
                    onChanged: (v) => setState(() => f = f.copyWith(openNow: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: f.count == 0 ? 'Tampilkan semua kedai' : 'Terapkan ${f.count} filter',
              onPressed: () => Navigator.pop(context, f),
            ),
          ],
        ),
      ),
    );
  }
}
