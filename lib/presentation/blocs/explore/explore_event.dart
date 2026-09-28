part of 'explore_bloc.dart';

abstract class ExploreEvent extends Equatable {
  const ExploreEvent();

  @override
  List<Object?> get props => [];
}

class ExploreLoadShops extends ExploreEvent {
  final UserLocation location;
  const ExploreLoadShops(this.location);

  @override
  List<Object?> get props => [location];
}

class ExploreFilterChanged extends ExploreEvent {
  final String? vibe;
  final bool? isOpen;
  final int? maxPrice;
  const ExploreFilterChanged({this.vibe, this.isOpen, this.maxPrice});

  @override
  List<Object?> get props => [vibe, isOpen, maxPrice];
}

class ExploreSearchChanged extends ExploreEvent {
  final String query;
  final UserLocation location;
  const ExploreSearchChanged({required this.query, required this.location});

  @override
  List<Object?> get props => [query, location];
}

class ExploreRefresh extends ExploreEvent {
  final UserLocation location;
  const ExploreRefresh(this.location);

  @override
  List<Object?> get props => [location];
}
