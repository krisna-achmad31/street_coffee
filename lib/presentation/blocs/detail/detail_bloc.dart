import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../../domain/usecases/coffee_shop_usecases.dart';

// Events
abstract class DetailEvent extends Equatable {
  const DetailEvent();
  @override
  List<Object?> get props => [];
}

class DetailLoadShop extends DetailEvent {
  final String shopId;
  const DetailLoadShop(this.shopId);
  @override
  List<Object?> get props => [shopId];
}

// States
abstract class DetailState extends Equatable {
  const DetailState();
  @override
  List<Object?> get props => [];
}

class DetailInitial extends DetailState {}

class DetailLoading extends DetailState {}

class DetailLoaded extends DetailState {
  final CoffeeShop shop;
  const DetailLoaded(this.shop);
  @override
  List<Object?> get props => [shop];
}

class DetailError extends DetailState {
  final String message;
  const DetailError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class DetailBloc extends Bloc<DetailEvent, DetailState> {
  final GetShopById getShopById;

  DetailBloc({required this.getShopById}) : super(DetailInitial()) {
    on<DetailLoadShop>(_onLoadShop);
  }

  Future<void> _onLoadShop(
    DetailLoadShop event,
    Emitter<DetailState> emit,
  ) async {
    emit(DetailLoading());
    final result = await getShopById(event.shopId);
    result.fold(
      (failure) => emit(DetailError(failure.message)),
      (shop) => emit(DetailLoaded(shop)),
    );
  }
}
