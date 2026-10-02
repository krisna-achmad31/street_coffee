import 'package:equatable/equatable.dart';

class CoffeeShop extends Equatable {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewCount;
  final String priceRange; // e.g. "Rp 10k-20k"
  final int minPrice;
  final int maxPrice;
  final String vibe; // e.g. "Santai", "Deep Talk", "Nongkrong Skena"
  final List<String> vibes;
  final List<String> facilities; // ["WiFi", "Outdoor", "Musik", "Parkir"]
  final List<String> categories; // ["Manual Brew", "Murah", etc.]
  final String imageUrl;
  final List<String> galleryUrls;
  final List<MenuFavorite> menuFavorites;
  final String whatsappNumber; // International format e.g. "6281234567890"
  final bool isOpen;
  final String openUntil; // e.g. "23:00"
  final String openFrom; // e.g. "08:00"
  final String description;
  final bool isFeatured;
  final double? distanceKm; // nullable, computed at runtime

  // v2
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? googleMapsUrl;

  /// Firebase uid of the verified owner (Kedai Pro dashboard access).
  final String? ownerUid;

  /// basic | gerobak | pro | proPlus
  final String proTier;

  /// Has at least one active Street Pass partner promo.
  final bool isPartner;

  /// Featured slot is paid (must be labelled "Bersponsor").
  final bool isSponsored;

  /// The stored, hand-set open switch. [isOpen] is this AND within hours;
  /// forms must edit this one so they don't overwrite it after closing time.
  final bool? openFlag;

  const CoffeeShop({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewCount,
    required this.priceRange,
    required this.minPrice,
    required this.maxPrice,
    required this.vibe,
    required this.vibes,
    required this.facilities,
    required this.categories,
    required this.imageUrl,
    required this.galleryUrls,
    required this.menuFavorites,
    required this.whatsappNumber,
    required this.isOpen,
    required this.openUntil,
    required this.openFrom,
    required this.isFeatured,
    required this.description,
    this.distanceKm,
    this.instagramUrl,
    this.tiktokUrl,
    this.googleMapsUrl,
    this.ownerUid,
    this.proTier = 'basic',
    this.isPartner = false,
    this.isSponsored = false,
    this.openFlag,
  });

  CoffeeShop copyWith({double? distanceKm, bool? isFeatured, bool? isOpen}) {
    return CoffeeShop(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      rating: rating,
      reviewCount: reviewCount,
      priceRange: priceRange,
      minPrice: minPrice,
      maxPrice: maxPrice,
      vibe: vibe,
      vibes: vibes,
      facilities: facilities,
      categories: categories,
      imageUrl: imageUrl,
      galleryUrls: galleryUrls,
      menuFavorites: menuFavorites,
      whatsappNumber: whatsappNumber,
      isOpen: isOpen ?? this.isOpen,
      openUntil: openUntil,
      openFrom: openFrom,
      isFeatured: isFeatured ?? this.isFeatured,
      description: description,
      distanceKm: distanceKm ?? this.distanceKm,
      instagramUrl: instagramUrl,
      tiktokUrl: tiktokUrl,
      googleMapsUrl: googleMapsUrl,
      ownerUid: ownerUid,
      proTier: proTier,
      isPartner: isPartner,
      isSponsored: isSponsored,
      openFlag: openFlag,
    );
  }

  /// "350 m" / "1,2 km"
  String get distanceText {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) return '${(distanceKm! * 1000).round()} m';
    if (distanceKm! >= 10) return '${distanceKm!.round()} km';
    return '${distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  String get statusText => isOpen
      ? 'Buka · s/d ${openUntil.replaceAll(':', '.')}'
      : 'Tutup · buka ${openFrom.replaceAll(':', '.')}';

  String get hoursText =>
      '${openFrom.replaceAll(':', '.')} – ${openUntil.replaceAll(':', '.')}';

  bool get isPro => proTier != 'basic';

  /// Whether [now] falls inside "HH:mm"–"HH:mm" opening hours. Handles
  /// overnight hours (18:00–02:00). Unparseable hours never block.
  static bool withinHours(String from, String until, DateTime now) {
    int? mins(String t) {
      final p = t.split(':');
      final h = p.length == 2 ? int.tryParse(p[0]) : null;
      final m = p.length == 2 ? int.tryParse(p[1]) : null;
      return h == null || m == null ? null : h * 60 + m;
    }

    final a = mins(from), b = mins(until);
    if (a == null || b == null || a == b) return true;
    final n = now.hour * 60 + now.minute;
    return a < b ? n >= a && n < b : n >= a || n < b;
  }

  /// Missing/invalid coordinates are stored as (0, 0) — off the coast of
  /// Africa — so they must not produce a distance or a map pin.
  bool get hasLocation => latitude != 0 || longitude != 0;

  bool get canOrderViaWa => whatsappNumber.isNotEmpty;

  String get displayName => name.isEmpty ? 'Kedai tanpa nama' : name;

  @override
  List<Object?> get props => [id];
}

class MenuFavorite extends Equatable {
  final String name;
  final String imageUrl;
  final int? price;

  const MenuFavorite({
    required this.name,
    required this.imageUrl,
    this.price,
  });

  @override
  List<Object?> get props => [name];
}
