import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/repositories/admin_shop_repository.dart';

abstract class AdminShopDataSource {
  Future<String> createShop(ShopFormData data);
  Future<void> updateShop(String shopId, ShopFormData data);
  Future<void> deleteShop(String shopId);
  Future<void> setIsOpen(String shopId, bool isOpen);
  Future<String> uploadGalleryImage(String shopId, File imageFile);
}

class AdminShopDataSourceImpl implements AdminShopDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseDatabase _rtdb;
  final Uuid _uuid;

  AdminShopDataSourceImpl({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required FirebaseDatabase rtdb,
  })  : _firestore = firestore,
        _storage = storage,
        _rtdb = rtdb,
        _uuid = const Uuid();

  @override
  Future<String> createShop(ShopFormData data) async {
    final docRef = _firestore.collection(FirebasePaths.shops).doc();
    final shopId = docRef.id;

    // 1. Upload cover image
    String coverUrl = '';
    if (data.coverImageFile != null) {
      coverUrl = await _uploadFile(
        file: data.coverImageFile!,
        path: FirebasePaths.shopCover(shopId),
      );
    }

    // 2. Upload menu photos
    final menuFavorites = <Map<String, dynamic>>[];
    for (final item in data.menuItems) {
      String menuImageUrl = item.existingImageUrl ?? '';
      if (item.imageFile != null) {
        final filename = '${_uuid.v4()}.jpg';
        menuImageUrl = await _uploadFile(
          file: item.imageFile!,
          path: FirebasePaths.menuPhoto(shopId, filename),
        );
      }
      menuFavorites.add({
        'name': item.name,
        'imageUrl': menuImageUrl,
        'price': item.price,
      });
    }

    // 3. Write to Firestore
    await docRef.set({
      'name': data.name,
      'description': data.description,
      'address': data.address,
      'latitude': data.latitude,
      'longitude': data.longitude,
      'priceRange': data.priceRange,
      'minPrice': data.minPrice,
      'maxPrice': data.maxPrice,
      'vibe': data.vibe,
      'vibes': data.vibes,
      'facilities': data.facilities,
      'categories': data.categories,
      'imageUrl': coverUrl,
      'galleryUrls': [],
      'menuFavorites': menuFavorites,
      'whatsappNumber': data.whatsappNumber,
      'openFrom': data.openFrom,
      'openUntil': data.openUntil,
      'isOpen': data.isOpen,
      'isFeatured': data.isFeatured,
      'rating': 0.0,
      'reviewCount': 0,
      'instagramUrl': data.instagramUrl,
      'tiktokUrl': data.tiktokUrl,
      'googleMapsUrl': data.googleMapsUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 4. Seed RTDB presence node
    await _rtdb.ref(FirebasePaths.shopPresence(shopId)).set({
      'isOpen': data.isOpen,
      'updatedAt': ServerValue.timestamp,
    });

    return shopId;
  }

  @override
  Future<void> updateShop(String shopId, ShopFormData data) async {
    String? coverUrl;
    if (data.coverImageFile != null) {
      coverUrl = await _uploadFile(
        file: data.coverImageFile!,
        path: FirebasePaths.shopCover(shopId),
      );
    }

    final menuFavorites = <Map<String, dynamic>>[];
    for (final item in data.menuItems) {
      String menuImageUrl = item.existingImageUrl ?? '';
      if (item.imageFile != null) {
        final filename = '${_uuid.v4()}.jpg';
        menuImageUrl = await _uploadFile(
          file: item.imageFile!,
          path: FirebasePaths.menuPhoto(shopId, filename),
        );
      }
      menuFavorites.add({
        'name': item.name,
        'imageUrl': menuImageUrl,
        'price': item.price,
      });
    }

    final updateData = <String, dynamic>{
      'name': data.name,
      'description': data.description,
      'address': data.address,
      'latitude': data.latitude,
      'longitude': data.longitude,
      'priceRange': data.priceRange,
      'minPrice': data.minPrice,
      'maxPrice': data.maxPrice,
      'vibe': data.vibe,
      'vibes': data.vibes,
      'facilities': data.facilities,
      'categories': data.categories,
      'menuFavorites': menuFavorites,
      'whatsappNumber': data.whatsappNumber,
      'openFrom': data.openFrom,
      'openUntil': data.openUntil,
      'isOpen': data.isOpen,
      'isFeatured': data.isFeatured,
      'instagramUrl': data.instagramUrl,
      'tiktokUrl': data.tiktokUrl,
      'googleMapsUrl': data.googleMapsUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (coverUrl != null) updateData['imageUrl'] = coverUrl;

    await _firestore
        .collection(FirebasePaths.shops)
        .doc(shopId)
        .update(updateData);

    await _rtdb.ref(FirebasePaths.shopPresence(shopId)).update({
      'isOpen': data.isOpen,
      'updatedAt': ServerValue.timestamp,
    });
  }

  @override
  Future<void> deleteShop(String shopId) async {
    // Delete Firestore doc
    await _firestore.collection(FirebasePaths.shops).doc(shopId).delete();

    // Delete Storage folder (best-effort)
    try {
      final storageRef = _storage.ref('shops/$shopId');
      final items = await storageRef.listAll();
      for (final item in items.items) {
        await item.delete();
      }
      for (final prefix in items.prefixes) {
        final sub = await prefix.listAll();
        for (final item in sub.items) {
          await item.delete();
        }
      }
    } catch (_) {}

    // Remove RTDB node
    await _rtdb.ref(FirebasePaths.shopPresence(shopId)).remove();
  }

  @override
  Future<void> setIsOpen(String shopId, bool isOpen) async {
    // RTDB for real-time
    await _rtdb.ref(FirebasePaths.shopPresence(shopId)).update({
      'isOpen': isOpen,
      'updatedAt': ServerValue.timestamp,
    });
    // Sync Firestore (non-blocking)
    _firestore
        .collection(FirebasePaths.shops)
        .doc(shopId)
        .update({'isOpen': isOpen});
  }

  @override
  Future<String> uploadGalleryImage(String shopId, File imageFile) async {
    final filename = '${_uuid.v4()}.jpg';
    final url = await _uploadFile(
      file: imageFile,
      path: FirebasePaths.shopGallery(shopId, filename),
    );

    // Append to Firestore galleryUrls
    await _firestore.collection(FirebasePaths.shops).doc(shopId).update({
      'galleryUrls': FieldValue.arrayUnion([url]),
    });

    return url;
  }

  // ─── Private ────────────────────────────────────────────────────────────────

  Future<String> _uploadFile({
    required File file,
    required String path,
  }) async {
    final ref = _storage.ref(path);
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }
}
