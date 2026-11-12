import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';

/// Dedicated singleton service managing live GPS location updates every 25 seconds for employees.
class EmployeeLiveTrackingService {
  static final EmployeeLiveTrackingService _instance =
      EmployeeLiveTrackingService._internal();
  factory EmployeeLiveTrackingService() => _instance;
  EmployeeLiveTrackingService._internal();

  Timer? _trackingTimer;
  bool _isTracking = false;
  bool _isSending = false;
  String? _currentEmployeeId;
  ApiClient? _apiClient;

  bool get isTracking => _isTracking;
  String? get currentEmployeeId => _currentEmployeeId;

  /// Initialize with ApiClient
  void initialize(ApiClient apiClient) {
    _apiClient = apiClient;
  }

  /// Start live location tracking: sends initial fix immediately (T0), then every 25s
  Future<void> startTracking({String? employeeId, ApiClient? apiClient}) async {
    if (apiClient != null) {
      _apiClient = apiClient;
    }
    _apiClient ??= ApiClient();

    if (_isTracking) {
      debugPrint(
        '[LOCATION_TRACKING] Tracking is already active. Ignoring duplicate start request.',
      );
      return;
    }

    _isTracking = true;
    _currentEmployeeId = employeeId ?? 'EMP-CURRENT';
    debugPrint('[LOCATION_TRACKING] STARTED');

    // 1. Send immediate GPS update (T0)
    await _sendCurrentLocation();

    // 2. Schedule regular periodic updates every 25 seconds
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(seconds: 25), (_) async {
      if (!_isTracking) {
        _trackingTimer?.cancel();
        return;
      }
      await _sendCurrentLocation();
    });
  }

  /// Send single current location update with validation and concurrency lock
  Future<void> _sendCurrentLocation() async {
    if (_isSending) {
      debugPrint(
        '[LOCATION_TRACKING] Previous location transmission in progress, skipping concurrent request.',
      );
      return;
    }

    if (!_isTracking) {
      return;
    }

    _isSending = true;
    try {
      // 1. Check GPS Service Enabled
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint(
          '[LOCATION_TRACKING] employeeId: $_currentEmployeeId status: failed error: Location services disabled',
        );
        return;
      }

      // 2. Check Permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          debugPrint(
            '[LOCATION_TRACKING] employeeId: $_currentEmployeeId status: failed error: Location permission denied',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
          '[LOCATION_TRACKING] employeeId: $_currentEmployeeId status: failed error: Location permission permanently denied',
        );
        return;
      }

      // 3. Acquire High Accuracy Position Fix (12-second timeout)
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final double lat = position.latitude;
      final double lng = position.longitude;
      final double accuracy = position.accuracy;

      // 4. Validate Coordinates
      if (lat < -90.0 ||
          lat > 90.0 ||
          lng < -180.0 ||
          lng > 180.0 ||
          (lat == 0.0 && lng == 0.0)) {
        debugPrint(
          '[LOCATION_TRACKING] employeeId: $_currentEmployeeId status: failed error: Invalid coordinates ($lat, $lng)',
        );
        return;
      }

      final String nowUtc = DateTime.now().toUtc().toIso8601String();

      // 5. Transmit to Backend API
      if (_apiClient != null) {
        await _apiClient!.post(
          '/mobile/location/update',
          data: {
            'latitude': lat,
            'longitude': lng,
            'accuracy': accuracy > 0 ? accuracy : 10.0,
            'timestamp': nowUtc,
            'trackingType': 'ATTENDANCE',
          },
        );

        debugPrint('''[LOCATION_TRACKING] employeeId: $_currentEmployeeId
[LOCATION_TRACKING] latitude: $lat
[LOCATION_TRACKING] longitude: $lng
[LOCATION_TRACKING] accuracy: $accuracy
[LOCATION_TRACKING] timestamp: $nowUtc
[LOCATION_TRACKING] UPDATE SUCCESS
[LOCATION_TRACKING] NEXT UPDATE IN 25 SEC''');
      }
    } catch (e) {
      debugPrint(
        '[LOCATION_TRACKING] employeeId: $_currentEmployeeId status: failed error: $e',
      );
    } finally {
      _isSending = false;
    }
  }

  /// Trigger single immediate refresh if tracking is active
  Future<void> sendImmediateLocationIfActive() async {
    if (_isTracking) {
      await _sendCurrentLocation();
    }
  }

  /// Stop location tracking on Punch Out or Logout
  void stopTracking() {
    debugPrint('[LOCATION_TRACKING] STOPPED');
    _isTracking = false;
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _currentEmployeeId = null;
  }
}
