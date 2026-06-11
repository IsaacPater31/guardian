import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:guardian/core/app_constants.dart';
import 'package:guardian/core/app_logger.dart';
import 'package:guardian/models/alert_model.dart';
import 'package:vibration/vibration.dart';

/// Drives vibration and on-screen pulse for the latest **pending** alert.
class ActiveAlertHighlightService extends ChangeNotifier {
  ActiveAlertHighlightService._();
  static final ActiveAlertHighlightService instance =
      ActiveAlertHighlightService._();

  static const List<int> _vibrationPatternMs = [
    0,
    1000,
    500,
    1000,
    500,
    1000,
    500,
    1000,
    500,
    1000,
  ];

  String? _highlightedAlertId;
  Timer? _clearTimer;

  String? get highlightedAlertId => _highlightedAlertId;

  bool isHighlighted(String? alertId) =>
      alertId != null && alertId == _highlightedAlertId;

  /// Activates feedback for a pending alert from the community feed.
  Future<void> activate(AlertModel alert) async {
    if (alert.id == null || !alert.isPendingAttention) return;

    _clearTimer?.cancel();
    _highlightedAlertId = alert.id;
    notifyListeners();

    await _vibrateForActiveWindow();

    _clearTimer = Timer(AppDurations.activeAlertFeedback, () {
      if (_highlightedAlertId == alert.id) {
        _highlightedAlertId = null;
        notifyListeners();
      }
      _stopVibration();
    });
  }

  void clear() {
    _clearTimer?.cancel();
    _clearTimer = null;
    _highlightedAlertId = null;
    notifyListeners();
    _stopVibration();
  }

  Future<void> _vibrateForActiveWindow() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return;
      await Vibration.vibrate(pattern: _vibrationPatternMs, repeat: 0);
    } catch (e) {
      AppLogger.e('ActiveAlertHighlightService._vibrateForActiveWindow', e);
    }
  }

  Future<void> _stopVibration() async {
    try {
      await Vibration.cancel();
    } catch (e) {
      AppLogger.e('ActiveAlertHighlightService._stopVibration', e);
    }
  }
}
