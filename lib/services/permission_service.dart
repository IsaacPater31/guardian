import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<void> requestBasicPermissions() async {
    // Notificaciones (solo iOS/Android 13+)
    await Permission.notification.request();
    // Ubicación
    await Permission.locationWhenInUse.request();
    // Vibración/Sonido no requieren permisos explícitos, pero puedes pedir otros si quieres
  }

  static Future<bool> allGranted() async {
    final notif = await Permission.notification.isGranted;
    final loc = await Permission.locationWhenInUse.isGranted;
    return notif && loc;
  }
}
