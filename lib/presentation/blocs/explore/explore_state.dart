part of 'explore_bloc.dart';

abstract class ExploreState extends Equatable {
  const ExploreState();

  @override
  List<Object?> get props => [];
}

class ExploreInitial extends ExploreState {}

class ExploreLoading extends ExploreState {}

class ExploreLoaded extends ExploreState {
  final List<CoffeeShop> shops;
  final String? activeVibe;
  final bool? isOpenFilter;
  final int? maxPriceFilter;

  const ExploreLoaded({
    required this.shops,
    this.activeVibe,
    this.isOpenFilter,
    this.maxPriceFilter,
  });

  @override
  List<Object?> get props => [shops, activeVibe, isOpenFilter, maxPriceFilter];
}

class ExploreError extends ExploreState {
  final String message;
  const ExploreError(this.message);

  @override
  List<Object?> get props => [message];
}

class ExploreEmpty extends ExploreState {
  final String message;
  const ExploreEmpty(this.message);

  @override
  List<Object?> get props => [message];
}
