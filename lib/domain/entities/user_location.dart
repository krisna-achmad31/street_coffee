import 'package:equatable/equatable.dart';

class UserLocation extends Equatable {
  final double latitude;
  final double longitude;
  final String? cityName;
  final String? districtName;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.cityName,
    this.districtName,
  });

  String get displayName {
    if (districtName != null) return districtName!;
    if (cityName != null) return cityName!;
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  @override
  List<Object?> get props => [latitude, longitude];
}
