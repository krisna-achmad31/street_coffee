import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../domain/entities/user_location.dart';
import '../../blocs/location/location_bloc.dart';
import '../../widgets/ui/common.dart';

class PickLocationPage extends StatefulWidget {
  const PickLocationPage({super.key});

  @override
  State<PickLocationPage> createState() => _PickLocationPageState();
}

class _PickLocationPageState extends State<PickLocationPage> {
  final _search = TextEditingController();
  bool _searching = false;
  List<(String, String, UserLocation)> _results = const [];

  // Well-known Jaksel areas as quick picks until saved places ship.
  static const _areas = [
    ('Blok M', 'Melawai, Kebayoran Baru', -6.2441, 106.7991),
    ('Senopati', 'Selong, Kebayoran Baru', -6.2297, 106.8069),
    ('Kemang', 'Bangka, Mampang Prapatan', -6.2608, 106.8132),
    ('Cipete', 'Cilandak', -6.2748, 106.7995),
  ];

  Future<void> _runSearch(String q) async {
    if (q.trim().length < 3) return;
    setState(() => _searching = true);
    try {
      final found = await locationFromAddress('$q, Indonesia');
      final out = <(String, String, UserLocation)>[];
      for (final l in found.take(5)) {
        final marks = await placemarkFromCoordinates(l.latitude, l.longitude);
        final p = marks.isEmpty ? null : marks.first;
        out.add((
          p?.subLocality?.isNotEmpty == true ? p!.subLocality! : q,
          [p?.locality, p?.subAdministrativeArea]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .join(', '),
          UserLocation(
            latitude: l.latitude,
            longitude: l.longitude,
            districtName: p?.subLocality,
            cityName: p?.locality,
          ),
        ));
      }
      if (mounted) setState(() => _results = out);
    } catch (_) {
      if (mounted) showAppSnack(context, 'Lokasi tidak ditemukan', error: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pick(UserLocation loc) {
    context.read<LocationBloc>().add(LocationSet(loc));
    context.pop();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Pilih Lokasi', back: true),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _runSearch,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: 'Cari jalan, area, atau gedung…',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textMuted),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  MenuTile(
                    icon: Icons.my_location_rounded,
                    title: 'Gunakan lokasi saat ini',
                    subtitle: 'Pakai GPS perangkat',
                    highlighted: true,
                    trailing: Icons.gps_fixed_rounded,
                    onTap: () {
                      context.read<LocationBloc>().add(LocationGetCurrent());
                      context.pop();
                    },
                  ),
                  if (_results.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const OverlineLabel('Hasil pencarian'),
                    const SizedBox(height: 8),
                    for (final (t, s, loc) in _results)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: MenuTile(
                          icon: Icons.location_on_rounded,
                          title: t,
                          subtitle: s,
                          onTap: () => _pick(loc),
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  const OverlineLabel('Area populer'),
                  const SizedBox(height: 8),
                  for (final (t, s, lat, lng) in _areas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MenuTile(
                        icon: Icons.history_rounded,
                        title: t,
                        subtitle: s,
                        trailing: Icons.north_west_rounded,
                        onTap: () => _pick(UserLocation(
                            latitude: lat,
                            longitude: lng,
                            districtName: t,
                            cityName: 'Jakarta Selatan')),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
