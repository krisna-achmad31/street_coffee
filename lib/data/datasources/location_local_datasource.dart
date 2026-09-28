import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user_location.dart';

abstract class LocationLocalDataSource {
  Future<UserLocation> getCurrentLocation();
  Future<UserLocation> getLocationFromAddress(String address);
  Future<String> getAddressFromCoordinates(double lat, double lng);
  Future<void> saveLastLocation(UserLocation location);
  Future<UserLocation?> getLastSavedLocation();
}

class LocationLocalDataSourceImpl implements LocationLocalDataSource {
  final SharedPreferences prefs;

  LocationLocalDataSourceImpl({required this.prefs});

  static const String _latKey = 'last_lat';
  static const String _lngKey = 'last_lng';
  static const String _cityKey = 'last_city';
  static const String _districtKey = 'last_district';

  @override
  Future<UserLocation> getCurrentLocation() async {
    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );

    // Try to get city name
    String? city;
    String? district;
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        city = placemarks.first.locality;
        district = placemarks.first.subLocality;
      }
    } catch (_) {
      // Silently fail — location coordinates still valid
    }

    return UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      cityName: city,
      districtName: district,
    );
  }

  @override
  Future<UserLocation> getLocationFromAddress(String address) async {
    final locations = await locationFromAddress(address);
    if (locations.isEmpty) throw Exception('Address not found');

    final loc = locations.first;
    final placemarks = await placemarkFromCoordinates(
      loc.latitude,
      loc.longitude,
    );

    String? city;
    String? district;
    if (placemarks.isNotEmpty) {
      city = placemarks.first.locality;
      district = placemarks.first.subLocality;
    }

    return UserLocation(
      latitude: loc.latitude,
      longitude: loc.longitude,
      cityName: city,
      districtName: district ?? address,
    );
  }

  @override
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    final placemarks = await placemarkFromCoordinates(lat, lng);
    if (placemarks.isEmpty) return '$lat, $lng';
    final p = placemarks.first;
    return [p.street, p.subLocality, p.locality]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
  }

  @override
  Future<void> saveLastLocation(UserLocation location) async {
    await prefs.setDouble(_latKey, location.latitude);
    await prefs.setDouble(_lngKey, location.longitude);
    if (location.cityName != null) {
      await prefs.setString(_cityKey, location.cityName!);
    }
    if (location.districtName != null) {
      await prefs.setString(_districtKey, location.districtName!);
    }
  }

  @override
  Future<UserLocation?> getLastSavedLocation() async {
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (lat == null || lng == null) return null;

    return UserLocation(
      latitude: lat,
      longitude: lng,
      cityName: prefs.getString(_cityKey),
      districtName: prefs.getString(_districtKey),
    );
  }
}
