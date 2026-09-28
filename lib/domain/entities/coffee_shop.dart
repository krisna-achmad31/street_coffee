import 'package:equatable/equatable.dart';

class CoffeeShop extends Equatable {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewCount;
  final String priceRange;   // e.g. "Rp 10k-20k"
  final int minPrice;
  final int maxPrice;
  final String vibe;          // e.g. "Santai", "Deep Talk", "Nongkrong Skena"
  final List<String> vibes;
  final List<String> facilities;  // ["WiFi", "Outdoor", "Musik", "Parkir"]
  final List<String> categories;  // ["Manual Brew", "Murah", etc.]
  final String imageUrl;
  final List<String> galleryUrls;
  final List<MenuFavorite> menuFavorites;
  final String whatsappNumber;  // International format e.g. "6281234567890"
  final bool isOpen;
  final String openUntil;   // e.g. "23:00"
  final String openFrom;    // e.g. "08:00"
  final String description;
  final bool isFeatured;
  final double? distanceKm; // nullable, computed at runtime

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
  });

  CoffeeShop copyWith({double? distanceKm, bool? isFeatured}) {
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
      isOpen: isOpen,
      openUntil: openUntil,
      openFrom: openFrom,
      isFeatured: isFeatured ?? this.isFeatured,
      description: description,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  String get distanceText {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) {
      return '${(distanceKm! * 1000).toInt()}m away';
    }
    return '${distanceKm!.toStringAsFixed(1)}km away';
  }

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
