import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/coffee_shop.dart';

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
    super.distanceKm, required isFeatured,
  }) : super(isFeatured: true);

  factory CoffeeShopModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CoffeeShopModel(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      priceRange: data['priceRange'] ?? '',
      minPrice: data['minPrice'] ?? 0,
      maxPrice: data['maxPrice'] ?? 0,
      vibe: data['vibe'] ?? '',
      vibes: List<String>.from(data['vibes'] ?? []),
      facilities: List<String>.from(data['facilities'] ?? []),
      categories: List<String>.from(data['categories'] ?? []),
      imageUrl: data['imageUrl'] ?? '',
      galleryUrls: List<String>.from(data['galleryUrls'] ?? []),
      menuFavorites: (data['menuFavorites'] as List<dynamic>? ?? [])
          .map((e) => MenuFavorite(
                name: e['name'] ?? '',
                imageUrl: e['imageUrl'] ?? '',
                price: e['price'],
              ))
          .toList(),
      whatsappNumber: data['whatsappNumber'] ?? '',
      isOpen: data['isOpen'] ?? false,
      openUntil: data['openUntil'] ?? '22:00',
      openFrom: data['openFrom'] ?? '08:00',
      isFeatured: data['isFeatured'] ?? false,
      description: data['description'] ?? '',
    );
  }

  factory CoffeeShopModel.fromMap(Map<String, dynamic> data, String id) {
    return CoffeeShopModel(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      priceRange: data['priceRange'] ?? '',
      minPrice: data['minPrice'] ?? 0,
      maxPrice: data['maxPrice'] ?? 0,
      vibe: data['vibe'] ?? '',
      vibes: List<String>.from(data['vibes'] ?? []),
      facilities: List<String>.from(data['facilities'] ?? []),
      categories: List<String>.from(data['categories'] ?? []),
      imageUrl: data['imageUrl'] ?? '',
      galleryUrls: List<String>.from(data['galleryUrls'] ?? []),
      menuFavorites: (data['menuFavorites'] as List<dynamic>? ?? [])
          .map((e) => MenuFavorite(
                name: e['name'] ?? '',
                imageUrl: e['imageUrl'] ?? '',
                price: e['price'],
              ))
          .toList(),
      whatsappNumber: data['whatsappNumber'] ?? '',
      isOpen: data['isOpen'] ?? false,
      openUntil: data['openUntil'] ?? '22:00',
      openFrom: data['openFrom'] ?? '08:00',
      isFeatured: data['isFeatured'] ?? false,
      description: data['description'] ?? '',
    );
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
      'description': description,
    };
  }
}
