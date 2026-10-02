import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/user_location.dart';
import '../../../domain/usecases/location_usecases.dart';
import '../../../core/utils/failures.dart';
import '../../../core/utils/use_case.dart';

// Events
abstract class LocationEvent extends Equatable {
  const LocationEvent();
  @override
  List<Object?> get props => [];
}

class LocationGetCurrent extends LocationEvent {}

class LocationGetLast extends LocationEvent {}

class LocationSet extends LocationEvent {
  final UserLocation location;
  const LocationSet(this.location);
  @override
  List<Object?> get props => [location];
}

// States
abstract class LocationState extends Equatable {
  const LocationState();
  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {}

class LocationLoading extends LocationState {}

class LocationLoaded extends LocationState {
  final UserLocation location;
  const LocationLoaded(this.location);
  @override
  List<Object?> get props => [location];
}

class LocationError extends LocationState {
  final String message;
  final LocationIssue issue;
  const LocationError(this.message, [this.issue = LocationIssue.unavailable]);

  /// Permission problems get the "Izin lokasi" screen; the rest a retry.
  bool get isPermission =>
      issue == LocationIssue.permissionDenied ||
      issue == LocationIssue.permissionDeniedForever ||
      issue == LocationIssue.serviceDisabled;

  @override
  List<Object?> get props => [message, issue];
}

// BLoC
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final GetCurrentLocation getCurrentLocation;
  final GetLastSavedLocation getLastSavedLocation;

  LocationBloc({
    required this.getCurrentLocation,
    required this.getLastSavedLocation,
  }) : super(LocationInitial()) {
    on<LocationGetCurrent>(_onGetCurrent);
    on<LocationGetLast>(_onGetLast);
    on<LocationSet>(_onSet);
  }

  Future<void> _onGetCurrent(
    LocationGetCurrent event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());
    final result = await getCurrentLocation(const NoParams());
    result.fold(
      (failure) => emit(LocationError(
          failure.message,
          failure is LocationFailure ? failure.issue : LocationIssue.unavailable)),
      (location) => emit(LocationLoaded(location)),
    );
  }

  Future<void> _onGetLast(
    LocationGetLast event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());
    final result = await getLastSavedLocation(const NoParams());
    final saved = result.fold((_) => null, (l) => l);
    if (saved != null) {
      emit(LocationLoaded(saved));
    } else {
      // Unreadable cache is the same as no cache: ask the GPS.
      add(LocationGetCurrent());
    }
  }

  Future<void> _onSet(
    LocationSet event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoaded(event.location));
  }
}
