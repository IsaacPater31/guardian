import 'dart:async';
import 'dart:io';

import '../core/app_logger.dart';
import '../models/alert_model.dart';
import '../services/alert_service.dart';
import '../services/native_background_service.dart';
import '../services/user_service.dart';

/// Binds the home UI to alert streams and the Android background service.
///
/// **Why a handler:** owns presentation lifecycle (subscriptions, callbacks)
/// while [AlertService] owns domain rules and data orchestration.
class HomeHandler {
  static final HomeHandler _instance = HomeHandler._internal();
  factory HomeHandler() => _instance;
  HomeHandler._internal();

  final AlertService _alertService = AlertService();
  final UserService _userService = UserService();

  StreamSubscription<List<AlertModel>>? _alertsSubscription;
  bool _isInitialized = false;
  List<AlertModel> _lastKnownAlerts = [];
  final Set<String> _processedAlertIds = <String>{};

  Function(List<AlertModel>)? onAlertsUpdated;
  Function(AlertModel)? onNewAlertReceived;
  Function(bool)? onServiceStatusChanged;

  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.d('HomeHandler already initialised — refreshing alerts');
      await _loadRecentAlerts();
      return;
    }

    AppLogger.d('HomeHandler initialising');

    if (Platform.isAndroid) {
      try {
        await NativeBackgroundService.startService();
        AppLogger.d('Native background service started');
      } catch (e) {
        AppLogger.e('HomeHandler: could not start native background service', e);
      }
    }

    _startAlertsListener();
    await _loadRecentAlerts();

    _isInitialized = true;
    AppLogger.d('HomeHandler initialised');
  }

  Future<void> dispose() async {
    AppLogger.d('HomeHandler disposing (service remains active)');
    await _alertsSubscription?.cancel();
    _alertsSubscription = null;
    _isInitialized = false;
    _lastKnownAlerts.clear();
    _processedAlertIds.clear();
    AppLogger.d('HomeHandler disposed');
  }

  Future<void> disposeCompletely() async {
    AppLogger.d('HomeHandler completely disposing');
    await _alertsSubscription?.cancel();
    _alertsSubscription = null;

    if (Platform.isAndroid) {
      try {
        await NativeBackgroundService.stopService();
        AppLogger.d('Background service stopped on complete dispose');
      } catch (e) {
        AppLogger.e('HomeHandler.disposeCompletely: stop service error', e);
      }
    }

    _isInitialized = false;
    _lastKnownAlerts.clear();
    _processedAlertIds.clear();
    AppLogger.d('HomeHandler completely disposed');
  }

  Future<List<AlertModel>> getRecentAlerts() async {
    try {
      final alerts = await _alertService.getRecentAlerts();
      if (_userService.currentUser != null) {
        return alerts
            .where((a) => !_userService.isUserOwnerOfAlert(a.userId, a.userEmail))
            .toList();
      }
      return alerts;
    } catch (e) {
      AppLogger.e('HomeHandler.getRecentAlerts', e);
      return [];
    }
  }

  Future<List<AlertModel>> getAllRecentAlerts() async {
    try {
      return await _alertService.getRecentAlerts();
    } catch (e) {
      AppLogger.e('HomeHandler.getAllRecentAlerts', e);
      return [];
    }
  }

  Future<void> refreshRecentAlerts() async {
    AppLogger.d('HomeHandler: refreshing alerts');
    await _loadRecentAlerts();
  }

  Future<bool> isServiceRunning() async {
    if (Platform.isAndroid) return NativeBackgroundService.isServiceRunning();
    return false;
  }

  Future<void> startBackgroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await NativeBackgroundService.startService();
      onServiceStatusChanged?.call(true);
      AppLogger.d('Background service started');
    } catch (e) {
      AppLogger.e('HomeHandler.startBackgroundService', e);
    }
  }

  Future<void> stopBackgroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await NativeBackgroundService.stopService();
      onServiceStatusChanged?.call(false);
      AppLogger.d('Background service stopped');
    } catch (e) {
      AppLogger.e('HomeHandler.stopBackgroundService', e);
    }
  }

  Future<void> markAlertAsViewed(String alertId) async {
    try {
      await _alertService.markAlertAsViewed(alertId);
      AppLogger.d('Alert marked as viewed: $alertId');
    } catch (e) {
      AppLogger.e('HomeHandler.markAlertAsViewed', e);
    }
  }

  Future<void> _loadRecentAlerts() async {
    try {
      final alerts = await getAllRecentAlerts();
      AppLogger.d('Loaded ${alerts.length} recent alerts');

      onAlertsUpdated?.call(alerts);
      _lastKnownAlerts = alerts;

      for (final alert in alerts) {
        if (alert.id != null) _processedAlertIds.add(alert.id!);
      }
    } catch (e) {
      AppLogger.e('HomeHandler._loadRecentAlerts', e);
    }
  }

  void _startAlertsListener() {
    AppLogger.d('HomeHandler: starting alerts listener');

    _alertsSubscription = _alertService.getRecentAlertsStream().listen(
      (alerts) {
        AppLogger.d('Stream: ${alerts.length} alerts received');

        final currentUser = _userService.currentUser;
        if (currentUser == null) return;

        onAlertsUpdated?.call(alerts);

        final othersAlerts = alerts
            .where((a) => !_userService.isUserOwnerOfAlert(a.userId, a.userEmail))
            .toList();

        if (othersAlerts.isNotEmpty) {
          final latest = othersAlerts.first;
          if (latest.id != null && !_processedAlertIds.contains(latest.id)) {
            _processedAlertIds.add(latest.id!);
            onNewAlertReceived?.call(latest);
            AppLogger.d('New alert: ${latest.alertType}');
          }
        }

        _lastKnownAlerts = alerts;
      },
      onError: (error) => AppLogger.e('HomeHandler alerts stream error', error),
    );
  }
}
