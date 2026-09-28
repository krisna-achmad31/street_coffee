import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../core/utils/failures.dart';
import '../entities/coffee_shop.dart';

abstract class AdminShopRepository {
  /// Create new shop — uploads cover photo & menu photos to Storage,
  /// writes doc to Firestore, seeds RTDB presence node.
  Future<Either<Failure, String>> createShop({
    required ShopFormData data,
  });

  /// Update existing shop fields (selectively)
  Future<Either<Failure, void>> updateShop({
    required String shopId,
    required ShopFormData data,
  });

  /// Delete shop + all storage files + RTDB node
  Future<Either<Failure, void>> deleteShop(String shopId);

  /// Toggle isOpen in RTDB (real-time)
  Future<Either<Failure, void>> setIsOpen(String shopId, bool isOpen);

  /// Upload single additional gallery image, returns download URL
  Future<Either<Failure, String>> uploadGalleryImage({
    required String shopId,
    required File imageFile,
  });
}

class ShopFormData {
  final String name;
  final String description;
  final String address;
  final double latitude;
  final double longitude;
  final String priceRange;
  final int minPrice;
  final int maxPrice;
  final String vibe;
  final List<String> vibes;
  final List<String> facilities;
  final List<String> categories;
  final String whatsappNumber;
  final String openFrom;
  final String openUntil;
  final bool isOpen;
  final bool isFeatured;

  // Social media
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? googleMapsUrl;

  // Files (nullable = tidak diupdate)
  final File? coverImageFile;
  final List<MenuItemForm> menuItems;

  const ShopFormData({
    required this.name,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.priceRange,
    required this.minPrice,
    required this.maxPrice,
    required this.vibe,
    required this.vibes,
    required this.facilities,
    required this.categories,
    required this.whatsappNumber,
    required this.openFrom,
    required this.openUntil,
    required this.isOpen,
    required this.isFeatured,
    this.instagramUrl,
    this.tiktokUrl,
    this.googleMapsUrl,
    this.coverImageFile,
    required this.menuItems,
  });
}

class MenuItemForm {
  final String name;
  final int? price;
  final File? imageFile;
  final String? existingImageUrl; // used when editing

  const MenuItemForm({
    required this.name,
    this.price,
    this.imageFile,
    this.existingImageUrl,
  });
}
