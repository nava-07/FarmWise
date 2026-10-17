import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserLocation {
  final String address;
  final double lat;
  final double lon;

  UserLocation({required this.address, required this.lat, required this.lon});

  Map<String, dynamic> toJson() => {'address': address, 'lat': lat, 'lon': lon};

  factory UserLocation.fromJson(Map<String, dynamic> json) => UserLocation(
    address: json['address'] as String,
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
  );
}

class LocationProvider with ChangeNotifier {
  UserLocation? _userLocation;
  bool _isLoading = true;

  UserLocation? get userLocation => _userLocation;
  bool get isLoading => _isLoading;

  LocationProvider() {
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('userLocation');
      if (stored != null) {
        _userLocation = UserLocation.fromJson(
          jsonDecode(stored) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('Failed to load location: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateLocation(UserLocation loc) async {
    _userLocation = loc;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userLocation', jsonEncode(loc.toJson()));
    } catch (e) {
      debugPrint('Failed to save location: $e');
    }
  }

  Future<void> clearLocation() async {
    _userLocation = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userLocation');
    } catch (e) {
      debugPrint('Failed to clear location: $e');
    }
  }
}
