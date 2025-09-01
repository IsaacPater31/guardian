import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_background_service.dart';

class PermissionService {
  static const String _firstLaunchKey = 'guardian_first_launch';
  
  /// Verifica si es la primera vez que se ejecuta la aplicación
  static Future<bool> _isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstLaunchKey) ?? true;
  }
  
  /// Marca que la aplicación ya se ha ejecutado por primera vez
  static Future<void> _markFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
  }

  /// Solicita solo los permisos esenciales en la primera ejecución
  /// Primero optimización de batería, luego notificaciones
  static Future<void> requestAllPermissionsOnFirstLaunch() async {
    final isFirstLaunch = await _isFirstLaunch();
    if (!isFirstLaunch) {
      print('🔐 Not first launch, skipping permission requests');
      return;
    }
    
    print('🔐 First launch detected - Requesting battery optimization first...');
    
    try {
      // 1. Optimización de batería (primero)
      if (Platform.isAndroid) {
        print('🔐 Requesting battery optimization exemption...');
        try {
          await NativeBackgroundService.requestBatteryOptimizationExemption();
          print('🔋 Battery optimization exemption requested');
        } catch (e) {
          print('⚠️ Battery optimization request failed: $e');
        }
      }
      
      // 2. Notificaciones (después)
      print('🔐 Requesting notification permission...');
      final notificationStatus = await Permission.notification.request();
      print('📱 Notification permission status: $notificationStatus');
      
      // Marcar que ya se ha ejecutado por primera vez
      await _markFirstLaunchComplete();
      print('✅ First launch permissions completed');
      
    } catch (e) {
      print('❌ Error during permission requests: $e');
      await _markFirstLaunchComplete();
    }
  }

  /// Verifica si los permisos esenciales están concedidos (solo notificaciones inicialmente)
  static Future<bool> essentialPermissionsGranted() async {
    final notif = await Permission.notification.isGranted;
    
    // Por ahora solo verificamos notificaciones
    // La optimización de batería se verificará después
    return notif;
  }

  /// Verifica si todos los permisos necesarios están concedidos
  static Future<bool> allPermissionsGranted() async {
    final notif = await Permission.notification.isGranted;
    final loc = await Permission.locationWhenInUse.isGranted;
    
    bool batteryOptimized = true;
    if (Platform.isAndroid) {
      batteryOptimized = await NativeBackgroundService.isBatteryOptimizationIgnored();
    }
    
    return notif && loc && batteryOptimized;
  }

  /// Verifica permisos individuales
  static Future<bool> hasNotificationPermission() async {
    return await Permission.notification.isGranted;
  }

  static Future<bool> hasLocationPermission() async {
    return await Permission.locationWhenInUse.isGranted;
  }

  static Future<bool> hasBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return true;
    return await NativeBackgroundService.isBatteryOptimizationIgnored();
  }

  /// Método para solicitar permisos de ubicación cuando sea necesario (al enviar alertas)
  static Future<bool> requestLocationPermissionForAlerts() async {
    print('🔐 Requesting location permission for sending alerts...');
    
    try {
      final hasLocation = await hasLocationPermission();
      if (!hasLocation) {
        print('🔐 Location permission needed for sending alerts...');
        final status = await Permission.locationWhenInUse.request();
        print('📍 Location permission status: $status');
        return status.isGranted;
      } else {
        print('📍 Location permission already granted');
        return true;
      }
    } catch (e) {
      print('❌ Error requesting location permission: $e');
      return false;
    }
  }

  /// Métodos individuales para solicitar permisos (mantenidos para compatibilidad)
  static Future<void> requestNotificationPermission() async {
    await Permission.notification.request();
  }

  static Future<void> requestLocationPermission() async {
    await Permission.locationWhenInUse.request();
  }

  static Future<void> requestBatteryOptimizationExemption() async {
    if (Platform.isAndroid) {
      await NativeBackgroundService.requestBatteryOptimizationExemption();
    }
  }

  /// Método para resetear el estado de primera ejecución (útil para testing)
  static Future<void> resetFirstLaunchState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstLaunchKey);
    print('🔄 First launch state reset - permissions will be requested again');
  }

  /// Método legacy mantenido para compatibilidad
  static Future<void> requestBasicPermissions() async {
    await requestAllPermissionsOnFirstLaunch();
  }

  /// Método legacy mantenido para compatibilidad
  static Future<bool> allGranted() async {
    return await allPermissionsGranted();
  }

  /// Método legacy mantenido para compatibilidad
  static Future<bool> requestAllPermissions() async {
    try {
      await requestAllPermissionsOnFirstLaunch();
      final allGranted = await allPermissionsGranted();
      
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

  /// Método para solicitar permisos faltantes específicos
  static Future<void> requestMissingPermissions() async {
    print('🔐 Checking and requesting missing permissions...');
    
    try {
      final hasNotification = await hasNotificationPermission();
      if (!hasNotification) {
        print('🔐 Requesting missing notification permission...');
        await Permission.notification.request();
      }
      
      if (Platform.isAndroid) {
        final hasBatteryOptimization = await hasBatteryOptimizationExemption();
        if (!hasBatteryOptimization) {
          print('🔐 Requesting missing battery optimization exemption...');
          try {
            await NativeBackgroundService.requestBatteryOptimizationExemption();
          } catch (e) {
            print('⚠️ Battery optimization request failed: $e');
          }
        }
      }
      
      print('✅ Missing permissions requested');
    } catch (e) {
      print('❌ Error requesting missing permissions: $e');
    }
  }

  /// Método específico para solicitar optimización de batería
  static Future<void> requestBatteryOptimizationOnly() async {
    if (!Platform.isAndroid) return;
    
    print('🔐 Requesting battery optimization exemption only...');
    try {
      await NativeBackgroundService.requestBatteryOptimizationExemption();
      print('🔋 Battery optimization exemption requested successfully');
    } catch (e) {
      print('⚠️ Battery optimization request failed: $e');
    }
  }

  /// Método para solicitar optimización de batería cuando el usuario interactúe
  static Future<void> requestBatteryOptimizationOnInteraction() async {
    if (!Platform.isAndroid) return;
    
    print('🔐 User interaction detected - requesting battery optimization...');
    try {
      await NativeBackgroundService.requestBatteryOptimizationExemption();
      print('🔋 Battery optimization exemption requested on interaction');
    } catch (e) {
      print('⚠️ Battery optimization request failed: $e');
    }
  }

  /// Método para forzar la solicitud de todos los permisos (útil para testing)
  static Future<void> forceRequestAllPermissions() async {
    print('🔐 Force requesting all permissions...');
    
    try {
      await resetFirstLaunchState();
      await requestAllPermissionsOnFirstLaunch();
      print('✅ All permissions force requested');
    } catch (e) {
      print('❌ Error force requesting permissions: $e');
    }
  }
}
