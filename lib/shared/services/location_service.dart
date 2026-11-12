import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:quickboom_crm_customer/core/services/employee_live_tracking_service.dart';

enum LocationPermissionState {
  granted,
  denied,
  permanentlyDenied,
  servicesDisabled,
  unavailable,
}

enum TrackingMode {
  off,
  attendanceOnly,
  duringVisit,
  workingHours,
  activeTracking,
}

class LocationPoint {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final String trackingType;
  final String? attendanceId;
  final String? visitId;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.trackingType,
    this.attendanceId,
    this.visitId,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'timestamp': timestamp.toIso8601String(),
    'trackingType': trackingType,
    'attendanceId': attendanceId,
    'visitId': visitId,
  };
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  LocationPermissionState get permissionState =>
      EmployeeLiveTrackingService().isTracking
      ? LocationPermissionState.granted
      : LocationPermissionState.unavailable;

  TrackingMode get trackingMode => EmployeeLiveTrackingService().isTracking
      ? TrackingMode.activeTracking
      : TrackingMode.off;

  /// Check & request location permission
  Future<LocationPermissionState> requestLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionState.servicesDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionState.denied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionState.permanentlyDenied;
    }

    return LocationPermissionState.granted;
  }

  /// Get current GPS location point
  Future<LocationPoint?> getCurrentLocation({
    String trackingType = 'ATTENDANCE',
  }) async {
    try {
      final perm = await requestLocationPermission();
      if (perm != LocationPermissionState.granted) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now().toUtc(),
        trackingType: trackingType,
      );
    } catch (_) {
      return null;
    }
  }

  /// Start periodic tracking (delegates to EmployeeLiveTrackingService)
  void startPeriodicTracking({
    String? employeeId,
    Duration interval = const Duration(seconds: 25),
    String trackingType = 'ATTENDANCE',
  }) {
    EmployeeLiveTrackingService().startTracking(employeeId: employeeId);
  }

  /// Stop tracking
  void stopTracking() {
    EmployeeLiveTrackingService().stopTracking();
  }
}
