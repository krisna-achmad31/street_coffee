import 'package:dartz/dartz.dart';
import '../../core/utils/failures.dart';
import '../../core/utils/use_case.dart';
import '../entities/user_location.dart';
import '../repositories/location_repository.dart';

class GetCurrentLocation extends UseCase<UserLocation, NoParams> {
  final LocationRepository repository;
  GetCurrentLocation(this.repository);

  @override
  Future<Either<Failure, UserLocation>> call(NoParams params) async {
    return repository.getCurrentLocation();
  }
}

class GetLastSavedLocation extends UseCase<UserLocation?, NoParams> {
  final LocationRepository repository;
  GetLastSavedLocation(this.repository);

  @override
  Future<Either<Failure, UserLocation?>> call(NoParams params) async {
    return repository.getLastSavedLocation();
  }
}
