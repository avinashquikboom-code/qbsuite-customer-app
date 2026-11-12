import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

class PermissionService {
  Future<ph.PermissionStatus> checkLocationPermission() async {
    return await ph.Permission.locationWhenInUse.status;
  }

  Future<ph.PermissionStatus> requestLocationPermission() async {
    return await ph.Permission.locationWhenInUse.request();
  }

  Future<ph.PermissionStatus> checkCameraPermission() async {
    return await ph.Permission.camera.status;
  }

  Future<ph.PermissionStatus> requestCameraPermission() async {
    return await ph.Permission.camera.request();
  }

  /// Note: Android Photo Picker does not require broad media permissions.
  /// On modern Android and iOS, selecting individual media files uses the system
  /// photo picker without needing broad library permissions.
  Future<ph.PermissionStatus> checkPhotoPermission() async {
    return await ph.Permission.photos.status;
  }

  Future<ph.PermissionStatus> requestPhotoPermission() async {
    return await ph.Permission.photos.request();
  }

  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }
}
