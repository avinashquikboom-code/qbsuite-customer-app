import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final bool isSuccess;
  final Position? position;
  final String? errorMessage;
  final bool isPermissionDenied;
  final bool isGpsDisabled;

  LocationResult({
    required this.isSuccess,
    this.position,
    this.errorMessage,
    this.isPermissionDenied = false,
    this.isGpsDisabled = false,
  });

  factory LocationResult.success(Position position) {
    return LocationResult(isSuccess: true, position: position);
  }

  factory LocationResult.error(
    String message, {
    bool isPermissionDenied = false,
    bool isGpsDisabled = false,
  }) {
    return LocationResult(
      isSuccess: false,
      errorMessage: message,
      isPermissionDenied: isPermissionDenied,
      isGpsDisabled: isGpsDisabled,
    );
  }
}

class EmployeeLocationService {
  /// Request GPS position with safety checks, permission handling, fresh fix, and timeout.
  static Future<LocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 15),
    bool forceFresh = true,
  }) async {
    try {
      // 1. Check if location services (GPS) are enabled on the device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.error(
          'Location services (GPS) are disabled. Please turn on GPS on your device.',
          isGpsDisabled: true,
        );
      }

      // 2. Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.error(
            'Location permission was denied. Location is required to verify attendance.',
            isPermissionDenied: true,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.error(
          'Location permissions are permanently denied. Please enable them in app settings.',
          isPermissionDenied: true,
        );
      }

      // 3. Acquire fresh, high-accuracy GPS position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      return LocationResult.success(position);
    } on TimeoutException {
      if (!forceFresh) {
        // Fallback to last known position only if fresh fix is not strictly required
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            return LocationResult.success(lastKnown);
          }
        } catch (_) {}
      }

      return LocationResult.error(
        'GPS location request timed out. Please ensure you have an active GPS signal and clear sky view.',
      );
    } catch (e) {
      debugPrint('[LOCATION_SERVICE] Error obtaining position: $e');
      return LocationResult.error(
        'Unable to determine current location. Please check GPS settings and try again.',
      );
    }
  }

  /// Calculates geodesic distance between two points in meters.
  static double calculateDistanceMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
