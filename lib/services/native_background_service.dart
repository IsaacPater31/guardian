import 'dart:io';
import 'package:flutter/services.dart';

/// Servicio para controlar el servicio nativo de Android
class NativeBackgroundService {
  static const MethodChannel _channel = MethodChannel('guardian_background_service');
  
  static final NativeBackgroundService _instance = NativeBackgroundService._internal();
  factory NativeBackgroundService() => _instance;
  NativeBackgroundService._internal();

  /// Inicia el servicio nativo de Android
  static Future<bool> startService() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final bool result = await _channel.invokeMethod('startService');
      print('✅ Native background service started: $result');
      return result;
    } on PlatformException catch (e) {
      print('❌ Error starting native background service: ${e.message}');
      return false;
    }
  }

  /// Detiene el servicio nativo de Android
  static Future<bool> stopService() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final bool result = await _channel.invokeMethod('stopService');
      print('✅ Native background service stopped: $result');
      return result;
    } on PlatformException catch (e) {
      print('❌ Error stopping native background service: ${e.message}');
      return false;
    }
  }

  /// Verifica si el servicio nativo está ejecutándose
  static Future<bool> isServiceRunning() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final bool result = await _channel.invokeMethod('isServiceRunning');
      return result;
    } on PlatformException catch (e) {
      print('❌ Error checking native background service status: ${e.message}');
      return false;
    }
  }
}
