import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/coffee_shop_model.dart';

abstract class CoffeeShopRemoteDataSource {
  Future<List<CoffeeShopModel>> getNearbyShops({
    String? vibeFilter,
    bool? isOpenFilter,
    int? maxPriceFilter,
  });

  Future<List<CoffeeShopModel>> getFeaturedShops();

  Future<CoffeeShopModel> getShopById(String id);

  Future<List<CoffeeShopModel>> searchShops(String query);
}

class CoffeeShopRemoteDataSourceImpl implements CoffeeShopRemoteDataSource {
  final FirebaseFirestore firestore;

  CoffeeShopRemoteDataSourceImpl({required this.firestore});

  static const String _collection = 'coffee_shops';

  @override
  Future<List<CoffeeShopModel>> getNearbyShops({
    String? vibeFilter,
    bool? isOpenFilter,
    int? maxPriceFilter,
  }) async {
    Query<Map<String, dynamic>> query =
        firestore.collection(_collection).limit(50);

    // Apply filters (Firestore compound queries need composite index)
    if (vibeFilter != null && vibeFilter.isNotEmpty) {
      query = query.where('vibes', arrayContains: vibeFilter);
    }
    if (isOpenFilter != null) {
      query = query.where('isOpen', isEqualTo: isOpenFilter);
    }
    if (maxPriceFilter != null) {
      query = query.where('minPrice', isLessThanOrEqualTo: maxPriceFilter);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => CoffeeShopModel.fromFirestore(doc))
        .toList();
  }

  @override
  Future<List<CoffeeShopModel>> getFeaturedShops() async {
    final snapshot = await firestore
        .collection(_collection)
        .where('isFeatured', isEqualTo: true)
        .limit(10)
        .get();

    return snapshot.docs
        .map((doc) => CoffeeShopModel.fromFirestore(doc))
        .toList();
  }

  @override
  Future<CoffeeShopModel> getShopById(String id) async {
    final doc = await firestore.collection(_collection).doc(id).get();
    if (!doc.exists) throw Exception('Shop not found');
    return CoffeeShopModel.fromFirestore(doc);
  }

  @override
  Future<List<CoffeeShopModel>> searchShops(String query) async {
    // Simple prefix search on name (for advanced search use Algolia)
    final snapshot = await firestore
        .collection(_collection)
        .orderBy('name')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => CoffeeShopModel.fromFirestore(doc))
        .toList();
  }
}
