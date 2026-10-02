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
    // Geocoders often return "" rather than null for unknown parts.
    final district = districtName?.trim() ?? '';
    final city = cityName?.trim() ?? '';
    if (district.isNotEmpty) return district;
    if (city.isNotEmpty) return city;
    // Geocoding found no area name (common outside Indonesia).
    return 'Lokasi kamu';
  }

  @override
  List<Object?> get props => [latitude, longitude];
}
