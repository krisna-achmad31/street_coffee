import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Tidak ada koneksi internet']);
}

class LocationFailure extends Failure {
  const LocationFailure([super.message = 'Gagal mendapatkan lokasi']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Data cache tidak tersedia']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Data tidak ditemukan']);
}
