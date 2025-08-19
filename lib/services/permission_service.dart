import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PermissionService {
  static Future<void> requestBasicPermissions() async {
    print('🔐 Requesting notification permission...');
    // Permisos básicos
    await Permission.notification.request();
    
    print('🔐 Requesting location permission...');
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

  /// Verifica y solicita todos los permisos necesarios
  static Future<bool> requestAllPermissions() async {
    try {
      await requestBasicPermissions();
      
      // Verificar si todos los permisos fueron concedidos
      final allGranted = await PermissionService.allGranted();
      
      if (allGranted) {
        print('✅ All permissions granted successfully');
        return true;
      } else {
        print('⚠️ Some permissions were denied');
        return false;
      }
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return false;
    }
  }
}
