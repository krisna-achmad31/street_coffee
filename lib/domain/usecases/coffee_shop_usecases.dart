import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/failures.dart';
import '../../core/utils/use_case.dart';
import '../entities/coffee_shop.dart';
import '../entities/user_location.dart';
import '../repositories/coffee_shop_repository.dart';

// ─── GetNearbyShops ───────────────────────────────────────────────────────────

class GetNearbyShops extends UseCase<List<CoffeeShop>, GetNearbyShopsParams> {
  final CoffeeShopRepository repository;
  GetNearbyShops(this.repository);

  @override
  Future<Either<Failure, List<CoffeeShop>>> call(
    GetNearbyShopsParams params,
  ) async {
    return repository.getNearbyShops(
      location: params.location,
      vibeFilter: params.vibeFilter,
      isOpenFilter: params.isOpenFilter,
      maxPriceFilter: params.maxPriceFilter,
    );
  }
}

class GetNearbyShopsParams extends Equatable {
  final UserLocation location;
  final String? vibeFilter;
  final bool? isOpenFilter;
  final int? maxPriceFilter;

  const GetNearbyShopsParams({
    required this.location,
    this.vibeFilter,
    this.isOpenFilter,
    this.maxPriceFilter,
  });

  @override
  List<Object?> get props => [location, vibeFilter, isOpenFilter, maxPriceFilter];
}

// ─── GetFeaturedShops ─────────────────────────────────────────────────────────

class GetFeaturedShops extends UseCase<List<CoffeeShop>, NoParams> {
  final CoffeeShopRepository repository;
  GetFeaturedShops(this.repository);

  @override
  Future<Either<Failure, List<CoffeeShop>>> call(NoParams params) async {
    return repository.getFeaturedShops();
  }
}

// ─── GetShopById ──────────────────────────────────────────────────────────────

class GetShopById extends UseCase<CoffeeShop, String> {
  final CoffeeShopRepository repository;
  GetShopById(this.repository);

  @override
  Future<Either<Failure, CoffeeShop>> call(String id) async {
    return repository.getShopById(id);
  }
}

// ─── SearchShops ──────────────────────────────────────────────────────────────

class SearchShops extends UseCase<List<CoffeeShop>, SearchShopsParams> {
  final CoffeeShopRepository repository;
  SearchShops(this.repository);

  @override
  Future<Either<Failure, List<CoffeeShop>>> call(
    SearchShopsParams params,
  ) async {
    return repository.searchShops(
      query: params.query,
      location: params.location,
    );
  }
}

class SearchShopsParams extends Equatable {
  final String query;
  final UserLocation location;

  const SearchShopsParams({required this.query, required this.location});

  @override
  List<Object?> get props => [query, location];
}
