import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  /// Turns any thrown object into a user-facing failure. Raw exception text
  /// (`[cloud_firestore/unavailable] …`) is logged, never shown.
  static Failure from(Object error, [String fallback = 'Terjadi kesalahan. Coba lagi.']) {
    if (error is Failure) return error;
    debugPrint('Failure.from: $error');
    if (error is SocketException || error is TimeoutException) {
      return const NetworkFailure();
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable' ||
              'network-request-failed' ||
              'deadline-exceeded' ||
              'network-error':
          return const NetworkFailure();
        case 'permission-denied' || 'unauthenticated' || 'unauthorized':
          return const ServerFailure('Kamu tidak punya akses ke data ini.');
        case 'not-found' || 'object-not-found':
          return const NotFoundFailure();
        case 'failed-precondition':
          // Usually a composite index that is still building.
          return const ServerFailure(
              'Data sedang disiapkan server. Coba lagi beberapa menit lagi.');
        case 'resource-exhausted' || 'quota-exceeded':
          return const ServerFailure('Server lagi sibuk. Coba lagi sebentar.');
      }
    }
    return ServerFailure(fallback);
  }

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(
      [super.message = 'Koneksi internet bermasalah. Cek jaringanmu lalu coba lagi.']);
}

enum LocationIssue { permissionDenied, permissionDeniedForever, serviceDisabled, unavailable }

class LocationFailure extends Failure {
  final LocationIssue issue;
  const LocationFailure(
      [super.message = 'Gagal mendapatkan lokasi', this.issue = LocationIssue.unavailable]);

  @override
  List<Object?> get props => [message, issue];
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Data cache tidak tersedia']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Data tidak ditemukan']);
}
