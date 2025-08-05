import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<void> requestBasicPermissions() async {
    // Permisos básicos
    await Permission.notification.request();
    await Permission.locationWhenInUse.request();
  }

  static Future<bool> allGranted() async {
    final notif = await Permission.notification.isGranted;
    final loc = await Permission.locationWhenInUse.isGranted;
    
    return notif && loc;
  }

  static Future<bool> hasNotificationPermission() async {
    return await Permission.notification.isGranted;
  }

  static Future<bool> hasLocationPermission() async {
    return await Permission.locationWhenInUse.isGranted;
  }

  static Future<void> requestNotificationPermission() async {
    await Permission.notification.request();
  }

  static Future<void> requestLocationPermission() async {
    await Permission.locationWhenInUse.request();
  }
}
