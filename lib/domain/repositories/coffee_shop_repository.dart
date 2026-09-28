import 'package:dartz/dartz.dart';
import '../../core/utils/failures.dart';
import '../entities/coffee_shop.dart';
import '../entities/user_location.dart';

abstract class CoffeeShopRepository {
  /// Fetch all coffee shops, sorted by distance from [location]
  Future<Either<Failure, List<CoffeeShop>>> getNearbyShops({
    required UserLocation location,
    String? vibeFilter,
    bool? isOpenFilter,
    int? maxPriceFilter,
  });

  /// Fetch featured/sponsored shops for home carousel
  Future<Either<Failure, List<CoffeeShop>>> getFeaturedShops();

  /// Get single shop detail by ID
  Future<Either<Failure, CoffeeShop>> getShopById(String id);

  /// Search shops by keyword
  Future<Either<Failure, List<CoffeeShop>>> searchShops({
    required String query,
    required UserLocation location,
  });
}
