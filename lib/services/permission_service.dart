import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_logger.dart';
import 'native_background_service.dart';

/// Manages runtime-permission requests for the Guardian app.
///
/// On the first launch, it requests notification and battery-optimisation
/// permissions with appropriate delays to avoid overwhelming the user.
/// Location permissions are requested on-demand (when the user sends an alert).
class PermissionService {
  static const String _firstLaunchKey = 'guardian_first_launch';

  // ─── First-launch check ──────────────────────────────────────────────────

  static Future<bool> _isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstLaunchKey) ?? true;
  }

  static Future<void> _markFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
  }

  // ─── First-launch permission flow ────────────────────────────────────────

  /// Requests essential permissions on first launch with UX-friendly delays.
  ///
  /// Safe to call on every startup — it is a no-op on subsequent launches.
  static Future<void> requestAllPermissionsOnFirstLaunch() async {
    if (!await _isFirstLaunch()) {
      AppLogger.d('PermissionService: not first launch, skipping');
      return;
    }

    AppLogger.d('PermissionService: first launch — starting permission flow');

    try {
      await _requestNotificationPermission();
      AppLogger.d('PermissionService: waiting 3 s for user to enable notifications');
      await Future.delayed(const Duration(seconds: 3));

      if (Platform.isAndroid) {
        await _requestBatteryOptimisation();
      }

      await _markFirstLaunchComplete();
      AppLogger.d('PermissionService: first-launch flow complete');
    } catch (e) {
      AppLogger.e('PermissionService.requestAllPermissionsOnFirstLaunch', e);
      await _markFirstLaunchComplete();
    }
  }

  // ─── Essential-permissions check ─────────────────────────────────────────

  /// Returns whether notification permission is granted.
  static Future<bool> essentialPermissionsGranted() async {
    if (Platform.isAndroid) {
      try {
        return await NativeBackgroundService.checkNotificationPermissions();
      } catch (e) {
        AppLogger.e('PermissionService.essentialPermissionsGranted', e);
        return Permission.notification.isGranted;
      }
    }
    return Permission.notification.isGranted;
  }

  /// Returns whether all permissions (notification + location + battery) are granted.
  static Future<bool> allPermissionsGranted() async {
    final notif = await Permission.notification.isGranted;
    final loc = await Permission.locationWhenInUse.isGranted;

    bool batteryOk = true;
    if (Platform.isAndroid) {
      batteryOk = await NativeBackgroundService.isBatteryOptimizationIgnored();
    }

    return notif && loc && batteryOk;
  }

  // ─── Individual permission checks ────────────────────────────────────────

  static Future<bool> hasNotificationPermission() async {
    if (Platform.isAndroid) {
      try {
        return await NativeBackgroundService.checkNotificationPermissions();
      } catch (e) {
        AppLogger.e('PermissionService.hasNotificationPermission', e);
        return Permission.notification.isGranted;
      }
    }
    return Permission.notification.isGranted;
  }

  /// Alias for [hasNotificationPermission] — kept for call-site compatibility.
  static Future<bool> checkNotificationPermissions() => hasNotificationPermission();

  static Future<bool> hasLocationPermission() async =>
      Permission.locationWhenInUse.isGranted;

  static Future<bool> hasBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return true;
    return NativeBackgroundService.isBatteryOptimizationIgnored();
  }

  // ─── On-demand location permission ───────────────────────────────────────

  /// Requests location permission and returns whether it is now granted.
  ///
  /// This is called just before sending an alert, not at startup, so the
  /// system dialog appears in a meaningful context.
  static Future<bool> requestLocationPermissionForAlerts() async {
    AppLogger.d('PermissionService: requesting location for alerts');
    try {
      if (await hasLocationPermission()) return true;
      final status = await Permission.locationWhenInUse.request();
      AppLogger.d('PermissionService: location status = $status');
      return status.isGranted;
    } catch (e) {
      AppLogger.e('PermissionService.requestLocationPermissionForAlerts', e);
      return false;
    }
  }

  // ─── Missing-permissions retry ────────────────────────────────────────────

  /// Requests any permissions that are still missing after first launch.
  static Future<void> requestMissingPermissions() async {
    AppLogger.d('PermissionService: requesting missing permissions');
    try {
      if (!await hasNotificationPermission()) {
        await _requestNotificationPermission();
        await Future.delayed(const Duration(seconds: 3));
      }

      if (Platform.isAndroid && !await hasBatteryOptimizationExemption()) {
        await _requestBatteryOptimisation();
      }

      AppLogger.d('PermissionService: missing-permission retry complete');
    } catch (e) {
      AppLogger.e('PermissionService.requestMissingPermissions', e);
    }
  }

  // ─── Diagnostics / testing helpers ───────────────────────────────────────

  /// Resets the first-launch flag so permission dialogs will show again.
  ///
  /// Intended for development / QA use only.
  static Future<void> resetFirstLaunchState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstLaunchKey);
    AppLogger.d('PermissionService: first-launch state reset');
  }

  /// Forces the full permission flow regardless of launch history.
  static Future<void> forceRequestAllPermissions() async {
    await resetFirstLaunchState();
    await requestAllPermissionsOnFirstLaunch();
  }

  // ─── Legacy shims (kept for call-site compatibility) ─────────────────────

  static Future<void> requestBasicPermissions() =>
      requestAllPermissionsOnFirstLaunch();

  static Future<bool> allGranted() => allPermissionsGranted();

  static Future<bool> requestAllPermissions() async {
    try {
      await requestAllPermissionsOnFirstLaunch();
      return allPermissionsGranted();
    } catch (e) {
      AppLogger.e('PermissionService.requestAllPermissions', e);
      return false;
    }
  }

  static Future<void> requestNotificationPermission() =>
      _requestNotificationPermission();

  static Future<void> requestLocationPermission() =>
      Permission.locationWhenInUse.request();

  static Future<void> requestBatteryOptimizationExemption() =>
      _requestBatteryOptimisation();

  static Future<void> requestBatteryOptimizationOnly() =>
      _requestBatteryOptimisation();

  static Future<void> requestBatteryOptimizationOnInteraction() =>
      _requestBatteryOptimisation();

  // ─── Private helpers ──────────────────────────────────────────────────────

  static Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      try {
        await NativeBackgroundService.requestNotificationPermissions();
        AppLogger.d('PermissionService: Android notification permission requested');
      } catch (e) {
        AppLogger.e('PermissionService._requestNotificationPermission', e);
        await Permission.notification.request();
      }
    } else {
      await Permission.notification.request();
    }
  }

  static Future<void> _requestBatteryOptimisation() async {
    if (!Platform.isAndroid) return;
    try {
      await NativeBackgroundService.requestBatteryOptimizationExemption();
      AppLogger.d('PermissionService: battery optimisation exemption requested');
    } catch (e) {
      AppLogger.e('PermissionService._requestBatteryOptimisation', e);
    }
  }
}
