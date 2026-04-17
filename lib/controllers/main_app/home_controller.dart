import 'dart:async';
import 'dart:io';
import '../../core/app_logger.dart';
import '../../models/alert_model.dart';
import '../../services/alert_repository.dart';
import '../../services/user_service.dart';
import '../../services/native_background_service.dart';

/// Coordinates alert streaming and the native background service for the
/// home screen.
///
/// Implemented as a singleton because initialisation (starting the background
/// service, subscribing to the Firestore stream) must happen only once per
/// app session.
class HomeController {
  static final HomeController _instance = HomeController._internal();
  factory HomeController() => _instance;
  HomeController._internal();

  final AlertRepository _alertRepository = AlertRepository();
  final UserService _userService = UserService();

  StreamSubscription<List<AlertModel>>? _alertsSubscription;
  bool _isInitialized = false;
  List<AlertModel> _lastKnownAlerts = [];
  final Set<String> _processedAlertIds = <String>{};

  // ─── UI callbacks ─────────────────────────────────────────────────────────

  Function(List<AlertModel>)? onAlertsUpdated;
  Function(AlertModel)? onNewAlertReceived;
  Function(bool)? onServiceStatusChanged;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  /// Initialises the controller. Safe to call multiple times.
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.d('HomeController already initialised — refreshing alerts');
      await _loadRecentAlerts();
      return;
    }

    AppLogger.d('HomeController initialising');

    if (Platform.isAndroid) {
      try {
        await NativeBackgroundService.startService();
        AppLogger.d('Native background service started');
      } catch (e) {
        AppLogger.e('HomeController: could not start native background service', e);
      }
    }

    _startAlertsListener();
    await _loadRecentAlerts();

    _isInitialized = true;
    AppLogger.d('HomeController initialised');
  }

  /// Cancels the stream subscription and resets state.
  ///
  /// The native background service is NOT stopped — it must keep running while
  /// the device is locked. Use [disposeCompletely] only when the app is
  /// definitively closing.
  Future<void> dispose() async {
    AppLogger.d('HomeController disposing (service remains active)');
    await _alertsSubscription?.cancel();
    _alertsSubscription = null;
    _isInitialized = false;
    _lastKnownAlerts.clear();
    _processedAlertIds.clear();
    AppLogger.d('HomeController disposed');
  }

  /// Full teardown including stopping the background service.
  Future<void> disposeCompletely() async {
    AppLogger.d('HomeController completely disposing');
    await _alertsSubscription?.cancel();
    _alertsSubscription = null;

    if (Platform.isAndroid) {
      try {
        await NativeBackgroundService.stopService();
        AppLogger.d('Background service stopped on complete dispose');
      } catch (e) {
        AppLogger.e('HomeController.disposeCompletely: stop service error', e);
      }
    }

    _isInitialized = false;
    _lastKnownAlerts.clear();
    _processedAlertIds.clear();
    AppLogger.d('HomeController completely disposed');
  }

  // ─── Alert queries ────────────────────────────────────────────────────────

  /// Returns recent alerts excluding the current user's own alerts.
  Future<List<AlertModel>> getRecentAlerts() async {
    try {
      final alerts = await _alertRepository.getRecentAlerts();
      if (_userService.currentUser != null) {
        return alerts
            .where((a) => !_userService.isUserOwnerOfAlert(a.userId, a.userEmail))
            .toList();
      }
      return alerts;
    } catch (e) {
      AppLogger.e('HomeController.getRecentAlerts', e);
      return [];
    }
  }

  /// Returns all recent alerts (own + received).
  Future<List<AlertModel>> getAllRecentAlerts() async {
    try {
      return await _alertRepository.getRecentAlerts();
    } catch (e) {
      AppLogger.e('HomeController.getAllRecentAlerts', e);
      return [];
    }
  }

  /// Triggers a manual refresh of recent alerts.
  Future<void> refreshRecentAlerts() async {
    AppLogger.d('HomeController: refreshing alerts');
    await _loadRecentAlerts();
  }

  // ─── Background service control ───────────────────────────────────────────

  /// Returns whether the native background service is currently running.
  Future<bool> isServiceRunning() async {
    if (Platform.isAndroid) return NativeBackgroundService.isServiceRunning();
    return false;
  }

  /// Starts the native background service.
  Future<void> startBackgroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await NativeBackgroundService.startService();
      onServiceStatusChanged?.call(true);
      AppLogger.d('Background service started');
    } catch (e) {
      AppLogger.e('HomeController.startBackgroundService', e);
    }
  }

  /// Stops the native background service.
  Future<void> stopBackgroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await NativeBackgroundService.stopService();
      onServiceStatusChanged?.call(false);
      AppLogger.d('Background service stopped');
    } catch (e) {
      AppLogger.e('HomeController.stopBackgroundService', e);
    }
  }

  // ─── View interactions ────────────────────────────────────────────────────

  /// Records the current user as a viewer of [alertId].
  Future<void> markAlertAsViewed(String alertId) async {
    try {
      await _alertRepository.markAlertAsViewed(alertId);
      AppLogger.d('Alert marked as viewed: $alertId');
    } catch (e) {
      AppLogger.e('HomeController.markAlertAsViewed', e);
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  Future<void> _loadRecentAlerts() async {
    try {
      final alerts = await getAllRecentAlerts();
      AppLogger.d('Loaded ${alerts.length} recent alerts');

      onAlertsUpdated?.call(alerts);
      _lastKnownAlerts = alerts;

      // Mark existing alerts as processed to prevent duplicate notifications.
      for (final alert in alerts) {
        if (alert.id != null) _processedAlertIds.add(alert.id!);
      }
    } catch (e) {
      AppLogger.e('HomeController._loadRecentAlerts', e);
    }
  }

  void _startAlertsListener() {
    AppLogger.d('HomeController: starting alerts listener');

    _alertsSubscription = _alertRepository.getRecentAlertsStream().listen(
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
      onError: (error) => AppLogger.e('HomeController alerts stream error', error),
    );
  }
}