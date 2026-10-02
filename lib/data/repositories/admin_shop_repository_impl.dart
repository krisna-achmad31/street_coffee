import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../core/utils/failures.dart';
import '../../domain/repositories/admin_shop_repository.dart';
import '../datasources/admin_shop_datasource.dart';

class AdminShopRepositoryImpl implements AdminShopRepository {
  final AdminShopDataSource dataSource;

  AdminShopRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, String>> createShop({
    required ShopFormData data,
  }) async {
    try {
      final id = await dataSource.createShop(data);
      return Right(id);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal menyimpan data kedai. Coba lagi.'));
    }
  }

  @override
  Future<Either<Failure, void>> updateShop({
    required String shopId,
    required ShopFormData data,
  }) async {
    try {
      await dataSource.updateShop(shopId, data);
      return const Right(null);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal menyimpan data kedai. Coba lagi.'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteShop(String shopId) async {
    try {
      await dataSource.deleteShop(shopId);
      return const Right(null);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal menyimpan data kedai. Coba lagi.'));
    }
  }

  @override
  Future<Either<Failure, void>> setIsOpen(String shopId, bool isOpen) async {
    try {
      await dataSource.setIsOpen(shopId, isOpen);
      return const Right(null);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal menyimpan data kedai. Coba lagi.'));
    }
  }

  @override
  Future<Either<Failure, String>> uploadGalleryImage({
    required String shopId,
    required File imageFile,
  }) async {
    try {
      final url = await dataSource.uploadGalleryImage(shopId, imageFile);
      return Right(url);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal menyimpan data kedai. Coba lagi.'));
    }
  }
}
