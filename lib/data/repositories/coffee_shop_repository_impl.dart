import 'dart:math';
import 'package:dartz/dartz.dart';
import '../../core/utils/failures.dart';
import '../../domain/entities/coffee_shop.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/repositories/coffee_shop_repository.dart';
import '../datasources/coffee_shop_remote_datasource.dart';
import '../models/coffee_shop_model.dart';

class CoffeeShopRepositoryImpl implements CoffeeShopRepository {
  final CoffeeShopRemoteDataSource remoteDataSource;

  CoffeeShopRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<CoffeeShop>>> getNearbyShops({
    required UserLocation location,
    String? vibeFilter,
    bool? isOpenFilter,
    int? maxPriceFilter,
  }) async {
    try {
      final models = await remoteDataSource.getNearbyShops(
        vibeFilter: vibeFilter,
        isOpenFilter: isOpenFilter,
        maxPriceFilter: maxPriceFilter,
      );

      // Compute distance and sort
      final shops = models
          .map((m) => m.copyWith(
                distanceKm: _calculateDistance(
                  location.latitude,
                  location.longitude,
                  m.latitude,
                  m.longitude,
                ),
              ))
          .toList()
        ..sort((a, b) =>
            (a.distanceKm ?? 99999).compareTo(b.distanceKm ?? 99999));

      return Right(shops);
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CoffeeShop>>> getFeaturedShops() async {
    try {
      final models = await remoteDataSource.getFeaturedShops();
      return Right(models);
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CoffeeShop>> getShopById(String id) async {
    try {
      final model = await remoteDataSource.getShopById(id);
      return Right(model);
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CoffeeShop>>> searchShops({
    required String query,
    required UserLocation location,
  }) async {
    try {
      final models = await remoteDataSource.searchShops(query);
      final shops = models
          .map((m) => m.copyWith(
                distanceKm: _calculateDistance(
                  location.latitude,
                  location.longitude,
                  m.latitude,
                  m.longitude,
                ),
              ))
          .toList();
      return Right(shops);
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0; // Earth radius in km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) => deg * pi / 180;
}
