import 'dart:io';

import '../services/alert_service.dart';

/// Entry point from the UI for alert actions: delegates to [AlertService].
///
/// **Why a handler:** keeps widgets free of use-case orchestration; in a mobile
/// app this replaces an HTTP “controller” — it only forwards calls and will
/// later be the place for analytics or navigation side-effects if needed.
class AlertHandler {
  final AlertService _alertService = AlertService();

  Future<bool> sendDetailedAlert({
    required String alertType,
    String? description,
    List<File>? images,
    required bool shareLocation,
    required bool isAnonymous,
  }) =>
      _alertService.sendDetailedAlert(
        alertType: alertType,
        description: description,
        images: images,
        shareLocation: shareLocation,
        isAnonymous: isAnonymous,
      );

  Future<bool> sendQuickAlert({
    required String alertType,
    required bool isAnonymous,
  }) =>
      _alertService.sendQuickAlert(alertType: alertType, isAnonymous: isAnonymous);

  Future<bool> sendSwipedAlert({
    required String alertType,
    required bool isAnonymous,
    required List<String> communityIds,
    String? subtype,
    String? customDetail,
    List<String> attachmentPlaceholders = const [],
  }) =>
      _alertService.sendSwipedAlert(
        alertType: alertType,
        isAnonymous: isAnonymous,
        communityIds: communityIds,
        subtype: subtype,
        customDetail: customDetail,
        attachmentPlaceholders: attachmentPlaceholders,
      );

  Future<int> forwardAlert({
    required String alertId,
    required List<String> targetCommunityIds,
  }) =>
      _alertService.forwardAlert(alertId: alertId, targetCommunityIds: targetCommunityIds);

  Future<void> markAlertAsViewed(String alertId) => _alertService.markAlertAsViewed(alertId);

  Future<void> reportAlert(String alertId) => _alertService.reportAlert(alertId);

  Future<bool> hasLocationPermission() => _alertService.hasLocationPermission();

  Future<bool> requestLocationPermission() => _alertService.requestLocationPermission();
}
