import 'package:dartz/dartz.dart';
import '../../core/utils/failures.dart';
import '../entities/user_location.dart';

abstract class LocationRepository {
  Future<Either<Failure, UserLocation>> getCurrentLocation();
  Future<Either<Failure, UserLocation>> getLocationFromAddress(String address);
  Future<Either<Failure, String>> getAddressFromCoordinates(
    double lat,
    double lng,
  );
  Future<Either<Failure, void>> saveLastLocation(UserLocation location);
  Future<Either<Failure, UserLocation?>> getLastSavedLocation();
}
