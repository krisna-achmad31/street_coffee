import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/failures.dart';
import '../models/coffee_shop_model.dart';
import '../models/json_reader.dart';

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
    // Only one server-side filter: array-contains alone needs no composite
    // index. Combining it with isOpen / minPrice did, and failed at runtime
    // with failed-precondition as soon as a user picked two filters.
    Query<Map<String, dynamic>> query =
        firestore.collection(_collection).limit(vibeFilter == null ? 100 : 60);
    if (vibeFilter != null && vibeFilter.isNotEmpty) {
      query = query.where('vibes', arrayContains: vibeFilter);
    }

    final snapshot = await query.get();
    return parseEach(snapshot.docs, CoffeeShopModel.fromFirestore)
        .where((s) =>
            (isOpenFilter == null || s.isOpen == isOpenFilter) &&
            (maxPriceFilter == null || s.minPrice <= maxPriceFilter))
        .toList();
  }

  @override
  Future<List<CoffeeShopModel>> getFeaturedShops() async {
    final snapshot = await firestore
        .collection(_collection)
        .where('isFeatured', isEqualTo: true)
        .limit(10)
        .get();

    return parseEach(snapshot.docs, CoffeeShopModel.fromFirestore);
  }

  @override
  Future<CoffeeShopModel> getShopById(String id) async {
    final doc = await firestore.collection(_collection).doc(id).get();
    if (!doc.exists) throw const NotFoundFailure('Kedai ini sudah tidak ada.');
    return CoffeeShopModel.fromFirestore(doc);
  }

  @override
  Future<List<CoffeeShopModel>> searchShops(String query) async {
    query = query.trim();
    if (query.isEmpty) return const [];
    // Simple prefix search on name (for advanced search use Algolia)
    final snapshot = await firestore
        .collection(_collection)
        .orderBy('name')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(20)
        .get();

    return parseEach(snapshot.docs, CoffeeShopModel.fromFirestore);
  }
}
