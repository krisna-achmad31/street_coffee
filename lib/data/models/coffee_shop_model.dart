import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/coffee_shop.dart';
import '../../core/utils/whatsapp_launcher.dart';
import 'json_reader.dart';

class CoffeeShopModel extends CoffeeShop {
  const CoffeeShopModel({
    required super.id,
    required super.name,
    required super.address,
    required super.latitude,
    required super.longitude,
    required super.rating,
    required super.reviewCount,
    required super.priceRange,
    required super.minPrice,
    required super.maxPrice,
    required super.vibe,
    required super.vibes,
    required super.facilities,
    required super.categories,
    required super.imageUrl,
    required super.galleryUrls,
    required super.menuFavorites,
    required super.whatsappNumber,
    required super.isOpen,
    required super.openUntil,
    required super.openFrom,
    required super.description,
    required super.isFeatured,
    super.distanceKm,
    super.instagramUrl,
    super.tiktokUrl,
    super.googleMapsUrl,
    super.ownerUid,
    super.proTier,
    super.isPartner,
    super.isSponsored,
    super.openFlag,
  });

  factory CoffeeShopModel.fromFirestore(DocumentSnapshot doc) =>
      CoffeeShopModel.fromMap(Json.asMap(doc.data()), doc.id);

  factory CoffeeShopModel.fromMap(Map<String, dynamic> data, String id,
      {DateTime? now}) {
    final j = Json(data);
    final openFrom = normalizeHour(j.str('openFrom'), '08:00');
    final openUntil = normalizeHour(j.str('openUntil'), '22:00');
    final pro = j.obj('pro');
    final proUntil = pro.date('until');
    final proActive = proUntil != null && proUntil.isAfter(DateTime.now());
    final lat = j.dbl('latitude');
    final lng = j.dbl('longitude');
    final validCoords = lat.abs() <= 90 && lng.abs() <= 180;
    final minPrice = j.integer('minPrice').clamp(0, 1 << 31);
    final maxPrice = j.integer('maxPrice').clamp(0, 1 << 31);
    return CoffeeShopModel(
      id: id,
      name: j.str('name').trim(),
      address: j.str('address').trim(),
      latitude: validCoords ? lat : 0,
      longitude: validCoords ? lng : 0,
      rating: j.dbl('rating').clamp(0, 5).toDouble(),
      reviewCount: j.integer('reviewCount').clamp(0, 1 << 31),
      priceRange: j.str('priceRange').trim(),
      minPrice: minPrice,
      maxPrice: maxPrice < minPrice ? minPrice : maxPrice,
      vibe: j.str('vibe').trim(),
      vibes: j.strings('vibes'),
      facilities: j.strings('facilities'),
      categories: j.strings('categories'),
      imageUrl: Json.url(data['imageUrl']),
      galleryUrls: j.strings('galleryUrls').map(Json.url).where((u) => u.isNotEmpty).toList(),
      menuFavorites: [
        for (final m in j.list('menuFavorites'))
          if (m.str('name').trim().isNotEmpty)
            MenuFavorite(
              name: m.str('name').trim(),
              imageUrl: Json.url(m.raw['imageUrl']),
              price: switch (m.intOrNull('price')) { final p? when p > 0 => p, _ => null },
            ),
      ],
      whatsappNumber: WhatsAppLauncher.normalizePhone(j.str('whatsappNumber')),
      // The flag is set by hand and goes stale (still "Buka" at 23.30 for a
      // shop that closes at 13.00), so it only counts inside opening hours.
      isOpen: j.boolean('isOpen') &&
          CoffeeShop.withinHours(openFrom, openUntil, now ?? DateTime.now()),
      openUntil: openUntil,
      openFrom: openFrom,
      // v1 bug: the constructor forced isFeatured = true for every shop.
      isFeatured: j.boolean('isFeatured'),
      description: j.str('description').trim(),
      instagramUrl: j.strOrNull('instagramUrl'),
      tiktokUrl: j.strOrNull('tiktokUrl'),
      googleMapsUrl: j.strOrNull('googleMapsUrl'),
      ownerUid: j.strOrNull('ownerUid'),
      proTier: proActive ? (pro.strOrNull('tier') ?? 'basic') : 'basic',
      isPartner: j.boolean('isPartner'),
      isSponsored: j.boolean('isSponsored'),
      openFlag: j.boolean('isOpen'),
    );
  }

  /// "8", "8.30", "08:30", "8:30 " → "08:00" / "08:30"; garbage → [fallback].
  static String normalizeHour(String raw, String fallback) {
    final m = RegExp(r'^(\d{1,2})(?:[:.](\d{2}))?$').firstMatch(raw.trim());
    if (m == null) return fallback;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2) ?? '0');
    if (h > 24 || min > 59) return fallback;
    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'reviewCount': reviewCount,
      'priceRange': priceRange,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'vibe': vibe,
      'vibes': vibes,
      'facilities': facilities,
      'categories': categories,
      'imageUrl': imageUrl,
      'galleryUrls': galleryUrls,
      'menuFavorites': menuFavorites
          .map((m) => {
                'name': m.name,
                'imageUrl': m.imageUrl,
                'price': m.price,
              })
          .toList(),
      'whatsappNumber': whatsappNumber,
      'isOpen': isOpen,
      'openUntil': openUntil,
      'openFrom': openFrom,
      'isFeatured': isFeatured,
      'description': description,
      'instagramUrl': instagramUrl,
      'tiktokUrl': tiktokUrl,
      'googleMapsUrl': googleMapsUrl,
    };
  }
}
