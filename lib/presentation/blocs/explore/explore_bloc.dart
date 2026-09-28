import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../../domain/entities/user_location.dart';
import '../../../domain/usecases/coffee_shop_usecases.dart';

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
    on<ExploreLoadShops>(_onLoadShops);
    on<ExploreFilterChanged>(_onFilterChanged);
    on<ExploreSearchChanged>(_onSearchChanged);
    on<ExploreRefresh>(_onRefresh);
  }

  Future<void> _onLoadShops(
    ExploreLoadShops event,
    Emitter<ExploreState> emit,
  ) async {
    _lastLocation = event.location;
    emit(ExploreLoading());
    await _fetchShops(emit);
  }

  Future<void> _onFilterChanged(
    ExploreFilterChanged event,
    Emitter<ExploreState> emit,
  ) async {
    _activeVibe = event.vibe;
    _isOpenFilter = event.isOpen;
    _maxPriceFilter = event.maxPrice;

    if (_lastLocation == null) return;
    emit(ExploreLoading());
    await _fetchShops(emit);
  }

  Future<void> _onSearchChanged(
    ExploreSearchChanged event,
    Emitter<ExploreState> emit,
  ) async {
    if (event.query.isEmpty) {
      _lastLocation = event.location;
      await _fetchShops(emit);
      return;
    }

    emit(ExploreLoading());
    final result = await searchShops(
      SearchShopsParams(query: event.query, location: event.location),
    );

    result.fold(
      (failure) => emit(ExploreError(failure.message)),
      (shops) {
        if (shops.isEmpty) {
          emit(const ExploreEmpty('Kedai tidak ditemukan'));
        } else {
          emit(ExploreLoaded(shops: shops));
        }
      },
    );
  }

  Future<void> _onRefresh(
    ExploreRefresh event,
    Emitter<ExploreState> emit,
  ) async {
    _lastLocation = event.location;
    await _fetchShops(emit);
  }

  Future<void> _fetchShops(Emitter<ExploreState> emit) async {
    if (_lastLocation == null) return;

    final result = await getNearbyShops(
      GetNearbyShopsParams(
        location: _lastLocation!,
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
