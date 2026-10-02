import 'package:dartz/dartz.dart';
import '../../core/utils/failures.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_local_datasource.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationLocalDataSource localDataSource;

  LocationRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, UserLocation>> getCurrentLocation() async {
    try {
      final location = await localDataSource.getCurrentLocation();
      await localDataSource.saveLastLocation(location);
      return Right(location);
    } catch (e) {
      return Left(e is Failure ? e : const LocationFailure());
    }
  }

  @override
  Future<Either<Failure, UserLocation>> getLocationFromAddress(
    String address,
  ) async {
    try {
      final location = await localDataSource.getLocationFromAddress(address);
      return Right(location);
    } catch (e) {
      return Left(e is Failure ? e : const LocationFailure());
    }
  }

  @override
  Future<Either<Failure, String>> getAddressFromCoordinates(
    double lat,
    double lng,
  ) async {
    try {
      final address = await localDataSource.getAddressFromCoordinates(lat, lng);
      return Right(address);
    } catch (e) {
      return Left(e is Failure ? e : const LocationFailure());
    }
  }

  @override
  Future<Either<Failure, void>> saveLastLocation(UserLocation location) async {
    try {
      await localDataSource.saveLastLocation(location);
      return const Right(null);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, UserLocation?>> getLastSavedLocation() async {
    try {
      final location = await localDataSource.getLastSavedLocation();
      return Right(location);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }
}
