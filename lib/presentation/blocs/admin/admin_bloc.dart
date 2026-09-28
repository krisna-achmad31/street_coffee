import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/admin_shop_repository.dart';

// Events
abstract class AdminEvent extends Equatable {
  const AdminEvent();
  @override
  List<Object?> get props => [];
}

class AdminCreateShop extends AdminEvent {
  final ShopFormData data;
  const AdminCreateShop(this.data);
  @override
  List<Object?> get props => [data];
}

class AdminUpdateShop extends AdminEvent {
  final String shopId;
  final ShopFormData data;
  const AdminUpdateShop({required this.shopId, required this.data});
  @override
  List<Object?> get props => [shopId];
}

class AdminDeleteShop extends AdminEvent {
  final String shopId;
  const AdminDeleteShop(this.shopId);
  @override
  List<Object?> get props => [shopId];
}

class AdminToggleOpen extends AdminEvent {
  final String shopId;
  final bool isOpen;
  const AdminToggleOpen({required this.shopId, required this.isOpen});
  @override
  List<Object?> get props => [shopId, isOpen];
}

class AdminUploadGallery extends AdminEvent {
  final String shopId;
  final File imageFile;
  const AdminUploadGallery({required this.shopId, required this.imageFile});
  @override
  List<Object?> get props => [shopId];
}

// States
abstract class AdminState extends Equatable {
  const AdminState();
  @override
  List<Object?> get props => [];
}

class AdminIdle extends AdminState {}
class AdminSubmitting extends AdminState {}

class AdminSuccess extends AdminState {
  final String message;
  final String? createdShopId;
  const AdminSuccess({required this.message, this.createdShopId});
  @override
  List<Object?> get props => [message, createdShopId];
}

class AdminError extends AdminState {
  final String message;
  const AdminError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final AdminShopRepository _repository;

  AdminBloc({required AdminShopRepository repository})
      : _repository = repository,
        super(AdminIdle()) {
    on<AdminCreateShop>(_onCreate);
    on<AdminUpdateShop>(_onUpdate);
    on<AdminDeleteShop>(_onDelete);
    on<AdminToggleOpen>(_onToggleOpen);
    on<AdminUploadGallery>(_onUploadGallery);
  }

  Future<void> _onCreate(AdminCreateShop event, Emitter<AdminState> emit) async {
    emit(AdminSubmitting());
    final result = await _repository.createShop(data: event.data);
    result.fold(
      (f) => emit(AdminError(f.message)),
      (id) => emit(AdminSuccess(message: 'Kedai berhasil ditambahkan!', createdShopId: id)),
    );
  }

  Future<void> _onUpdate(AdminUpdateShop event, Emitter<AdminState> emit) async {
    emit(AdminSubmitting());
    final result = await _repository.updateShop(
        shopId: event.shopId, data: event.data);
    result.fold(
      (f) => emit(AdminError(f.message)),
      (_) => emit(const AdminSuccess(message: 'Kedai berhasil diupdate!')),
    );
  }

  Future<void> _onDelete(AdminDeleteShop event, Emitter<AdminState> emit) async {
    emit(AdminSubmitting());
    final result = await _repository.deleteShop(event.shopId);
    result.fold(
      (f) => emit(AdminError(f.message)),
      (_) => emit(const AdminSuccess(message: 'Kedai dihapus.')),
    );
  }

  Future<void> _onToggleOpen(
      AdminToggleOpen event, Emitter<AdminState> emit) async {
    final result =
        await _repository.setIsOpen(event.shopId, event.isOpen);
    result.fold(
      (f) => emit(AdminError(f.message)),
      (_) => emit(AdminSuccess(
          message: event.isOpen ? 'Status: BUKA' : 'Status: TUTUP')),
    );
  }

  Future<void> _onUploadGallery(
      AdminUploadGallery event, Emitter<AdminState> emit) async {
    emit(AdminSubmitting());
    final result = await _repository.uploadGalleryImage(
      shopId: event.shopId,
      imageFile: event.imageFile,
    );
    result.fold(
      (f) => emit(AdminError(f.message)),
      (_) => emit(const AdminSuccess(message: 'Foto gallery ditambahkan!')),
    );
  }
}
