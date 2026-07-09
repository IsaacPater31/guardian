import 'dart:io';
import 'package:flutter/services.dart';
import '../core/app_logger.dart';

/// Servicio simplificado para controlar el servicio nativo de Android.
/// Centraliza la comunicación con el servicio nativo vía MethodChannel.
class NativeBackgroundService {
  static const MethodChannel _channel = MethodChannel('guardian_background_service');

  static final NativeBackgroundService _instance = NativeBackgroundService._internal();
  factory NativeBackgroundService() => _instance;
  NativeBackgroundService._internal();

  /// Inicia el servicio nativo de Android.
  static Future<bool> startService() async {
    if (!Platform.isAndroid) return false;

    try {
      final bool result = await _channel.invokeMethod('startService');
      AppLogger.d('Native background service started: $result');
      return result;
    } on PlatformException catch (e) {
      AppLogger.e('NativeBackgroundService.startService', e.message ?? e);
      return false;
    }
  }

  /// Detiene el servicio nativo de Android.
  static Future<bool> stopService() async {
    if (!Platform.isAndroid) return false;

    try {
      final bool result = await _channel.invokeMethod('stopService');
      AppLogger.d('Native background service stopped: $result');
      return result;
    } on PlatformException catch (e) {
      AppLogger.e('NativeBackgroundService.stopService', e.message ?? e);
      return false;
    }
  }

  /// Verifica si el servicio nativo está ejecutándose.
  static Future<bool> isServiceRunning() async {
    if (!Platform.isAndroid) return false;

    try {
      final bool result = await _channel.invokeMethod('isServiceRunning');
      return result;
    } on PlatformException catch (e) {
      AppLogger.e('NativeBackgroundService.isServiceRunning', e.message ?? e);
      return false;
    }
  }

  /// Informa al servicio nativo si la app está en primer plano (evita notificaciones duplicadas).
  static Future<void> setAppForeground(bool foreground) async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('setAppForeground', {'foreground': foreground});
    } on PlatformException catch (e) {
      AppLogger.e('NativeBackgroundService.setAppForeground', e.message ?? e);
    }
  }

  /// Solicita exención de optimización de batería.
  static Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return false;

    try {
      final bool result =
          await _channel.invokeMethod('requestBatteryOptimizationExemption');
      AppLogger.d('Battery optimization exemption result: $result');
      return result;
    } on PlatformException catch (e) {
      AppLogger.e(
          'NativeBackgroundService.requestBatteryOptimizationExemption', e.message ?? e);
      return false;
    }
  }

  /// Verifica si la app está exenta de optimización de batería.
  static Future<bool> isBatteryOptimizationIgnored() async {
    if (!Platform.isAndroid) return false;

    try {
      final bool result = await _channel.invokeMethod('isBatteryOptimizationIgnored');
      return result;
    } on PlatformException catch (e) {
      AppLogger.e(
          'NativeBackgroundService.isBatteryOptimizationIgnored', e.message ?? e);
      return false;
    }
  }

  /// Verifica si las notificaciones están habilitadas para la app.
  static Future<bool> checkNotificationPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      final bool result = await _channel.invokeMethod('checkNotificationPermissions');
      AppLogger.d('Notification permissions check result: $result');
      return result;
    } on PlatformException catch (e) {
      AppLogger.e(
          'NativeBackgroundService.checkNotificationPermissions', e.message ?? e);
      return false;
    }
  }

  /// Solicita permisos de notificación (Android 13+).
  static Future<bool> requestNotificationPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      final bool result =
          await _channel.invokeMethod('requestNotificationPermissions');
      AppLogger.d('Notification permissions request result: $result');
      return result;
    } on PlatformException catch (e) {
      AppLogger.e(
          'NativeBackgroundService.requestNotificationPermissions', e.message ?? e);
      return false;
    }
  }

  /// True si el usuario abrió la app desde una notificación de mensaje de comunidad.
  static Future<bool> consumeOpenCommunityMessagesNavigation() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('consumeOpenCommunityMessages');
      return result ?? false;
    } on PlatformException catch (e) {
      AppLogger.e('NativeBackgroundService.consumeOpenCommunityMessagesNavigation', e.message ?? e);
      return false;
    }
  }
}
