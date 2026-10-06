import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/links.dart';

/// OpenStreetMap standard tiles: free, no API key. (CARTO's dark basemap
/// started requiring a key and stamped "API KEY REQUIRED" on every tile.)
///
/// OSM tile usage policy: send a real User-Agent (the app id), keep the
/// visible attribution, no bulk/offline downloading. If traffic grows, move
/// to self-hosted tiles (e.g. a Protomaps file) — only [_url] changes.
TileLayer osmTileLayer() => TileLayer(
      urlTemplate: _url,
      userAgentPackageName: 'com.streetcoffee.app.street_coffees',
      maxNativeZoom: 19,
      tileBuilder: _darkTile,
    );

const _url = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// OSM tiles are light; turn them into the app's near-black palette:
/// grayscale → invert → compress toward #0E0E0E so labels stay readable
/// but the map never competes with the lime pins.
const _k = 0.7;
const _c = 8.0;
const _darkMatrix = <double>[
  -0.2126 * _k, -0.7152 * _k, -0.0722 * _k, 0, 255 * _k + _c, //
  -0.2126 * _k, -0.7152 * _k, -0.0722 * _k, 0, 255 * _k + _c, //
  -0.2126 * _k, -0.7152 * _k, -0.0722 * _k, 0, 255 * _k + _c, //
  0, 0, 0, 1, 0,
];

Widget _darkTile(BuildContext context, Widget tile, TileImage _) =>
    ColorFiltered(colorFilter: const ColorFilter.matrix(_darkMatrix), child: tile);

/// Required "© OpenStreetMap" credit, small and out of the way.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openExternal(Uri.https('www.openstreetmap.org', '/copyright')),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xB30E0E0E),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('© OpenStreetMap',
            style: AppTextStyles.meta.copyWith(fontSize: 10, color: AppColors.textMuted)),
      ),
    );
  }
}
