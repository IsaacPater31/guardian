import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<void> requestBasicPermissions() async {
    await Permission.notification.request();
    await Permission.locationWhenInUse.request();
  }

  static Future<bool> allGranted() async {
    final notif = await Permission.notification.isGranted;
    final loc = await Permission.locationWhenInUse.isGranted;
    return notif && loc;
  }
}
