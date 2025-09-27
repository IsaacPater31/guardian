import 'package:flutter/services.dart';

class NativeService {
  static const MethodChannel _channel = MethodChannel('guardian_background_service');

  static Future<bool> startService() async {
    try {
      final res = await _channel.invokeMethod('startService');
      return res == true;
    } catch (e) {
      print('Error starting native service: $e');
      return false;
    }
  }

  static Future<bool> stopService() async {
    try {
      final res = await _channel.invokeMethod('stopService');
      return res == true;
    } catch (e) {
      print('Error stopping native service: $e');
      return false;
    }
  }

  static Future<bool> requestBatteryOptimizationExemption() async {
    try {
      await _channel.invokeMethod('requestBatteryOptimizationExemption');
      return true;
    } catch (e) {
      print('Error requesting battery opt exemption: $e');
      return false;
    }
  }

  static Future<bool> scheduleWorker() async {
    try {
      await _channel.invokeMethod('scheduleWorker');
      return true;
    } catch (e) {
      print('Error scheduling worker via native: $e');
      return false;
    }
  }
}
