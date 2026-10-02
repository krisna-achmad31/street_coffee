import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../../domain/entities/user_location.dart';
import '../../../domain/usecases/coffee_shop_usecases.dart';
import '../transformers.dart';

part 'explore_event.dart';
part 'explore_state.dart';

class ExploreBloc extends Bloc<ExploreEvent, ExploreState> {
  final GetNearbyShops getNearbyShops;
  final SearchShops searchShops;

  // Current filter state
  UserLocation? _lastLocation;
  String? _activeVibe;
  bool? _isOpenFilter;
  int? _maxPriceFilter;

  ExploreBloc({
    required this.getNearbyShops,
    required this.searchShops,
  }) : super(ExploreInitial()) {
    // One restartable handler for every fetch: typing fast, flipping filters
    // or a location change mid-request can't let a stale response win.
    on<ExploreEvent>(_onEvent, transformer: restartable);
  }

  Future<void> _onEvent(ExploreEvent event, Emitter<ExploreState> emit) async {
    switch (event) {
      case ExploreLoadShops(:final location):
        _lastLocation = location;
        emit(ExploreLoading());
        await _fetchShops(emit);
      case ExploreFilterChanged():
        _activeVibe = event.vibe;
        _isOpenFilter = event.isOpen;
        _maxPriceFilter = event.maxPrice;
        if (_lastLocation == null) return;
        emit(ExploreLoading());
        await _fetchShops(emit);
      case ExploreSearchChanged(:final query, :final location):
        _lastLocation = location;
        if (query.trim().isEmpty) {
          emit(ExploreLoading());
          await _fetchShops(emit);
          return;
        }
        emit(ExploreLoading());
        final result = await searchShops(
          SearchShopsParams(query: query.trim(), location: location),
        );
        result.fold(
          (failure) => emit(ExploreError(failure.message)),
          (shops) => emit(shops.isEmpty
              ? const ExploreEmpty('Kedai tidak ditemukan')
              : ExploreLoaded(shops: shops)),
        );
      case ExploreRefresh(:final location):
        // No loading state: the list stays visible under the refresh spinner.
        _lastLocation = location;
        await _fetchShops(emit);
    }
  }

  Future<void> _fetchShops(Emitter<ExploreState> emit) async {
    final location = _lastLocation;
    if (location == null) return;

    final result = await getNearbyShops(
      GetNearbyShopsParams(
        location: location,
        vibeFilter: _activeVibe,
        isOpenFilter: _isOpenFilter,
        maxPriceFilter: _maxPriceFilter,
      ),
    );

    result.fold(
      (failure) => emit(ExploreError(failure.message)),
      (shops) {
        if (shops.isEmpty) {
          emit(const ExploreEmpty('Belum ada kedai di area kamu'));
        } else {
          emit(ExploreLoaded(
            shops: shops,
            activeVibe: _activeVibe,
            isOpenFilter: _isOpenFilter,
            maxPriceFilter: _maxPriceFilter,
          ));
        }
      },
    );
  }
}
