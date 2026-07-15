import 'dart:io';

import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/alerts/domain/alert_model.dart';
import 'package:guardian/features/alerts/data/alert_repository.dart';
import 'package:guardian/features/alerts/application/coordinators/alert_access_resolver.dart';
import 'package:guardian/features/alerts/application/coordinators/alert_send_coordinator.dart';
import 'package:guardian/features/home_shell/application/location_service.dart';
import 'package:guardian/features/auth/application/user_service.dart';

/// Business rules for alerts: permissions, feed visibility, sending, forwarding.
///
/// Thin facade over [AlertAccessResolver] (feed visibility cache/filter) and
/// [AlertSendCoordinator] (send/forward use cases). Call sites keep importing
/// this type; singleton [AlertService] factory behavior is unchanged.
class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  final AlertRepository _alertRepository = AlertRepository();
  final UserService _userService = UserService();
  final AlertAccessResolver _access = AlertAccessResolver();
  final AlertSendCoordinator _send = AlertSendCoordinator();

  void invalidateCommunityCache() => _access.invalidate();

  // ─── Reads ───────────────────────────────────────────────────────────────

  Future<List<AlertModel>> getRecentAlerts() async {
    try {
      final since = DateTime.now().subtract(AppDurations.alertFeedWindow);
      final raw = await _alertRepository.fetchRecentAlertsSince(since);
      return _access.filterByPermissionsAndCommunity(
        raw,
        await _access.getUserCommunityAccess(),
      );
    } catch (e) {
      AppLogger.e('AlertService.getRecentAlerts', e);
      return [];
    }
  }

  Stream<List<AlertModel>> getRecentAlertsStream() {
    final since = DateTime.now().subtract(AppDurations.alertFeedWindow);
    return _alertRepository.watchRecentAlertsSince(since).asyncMap((
      raw,
    ) async {
      return _access.filterByPermissionsAndCommunity(
        raw,
        await _access.getUserCommunityAccess(),
      );
    });
  }

  Future<List<AlertModel>> getMapAlerts() async {
    try {
      final since = DateTime.now().subtract(AppDurations.mapAlertsWindow);
      final raw = await _alertRepository.fetchMapAlertsSince(since);
      final visible = raw.where((a) {
        if (!a.shareLocation || a.location == null) return false;
        return _userService.canUserViewAlert(
          a.userId,
          a.userEmail,
          a.isAnonymous,
        );
      }).toList();
      return _access.filterByPermissionsAndCommunity(
        visible,
        await _access.getUserCommunityAccess(),
      );
    } catch (e) {
      AppLogger.e('AlertService.getMapAlerts', e);
      return [];
    }
  }

  Stream<List<AlertModel>> getMapAlertsStream() {
    final since = DateTime.now().subtract(AppDurations.mapAlertsWindow);
    return _alertRepository.watchMapAlertsSince(since).asyncMap((
      alerts,
    ) async {
      final visible = alerts
          .where(
            (a) =>
                a.shareLocation &&
                a.location != null &&
                _userService.canUserViewAlert(
                  a.userId,
                  a.userEmail,
                  a.isAnonymous,
                ),
          )
          .toList();
      return _access.filterByPermissionsAndCommunity(
        visible,
        await _access.getUserCommunityAccess(),
      );
    });
  }

  Stream<List<AlertModel>> getMapAlertsStreamFiltered({
    List<String> selectedTypes = const [],
    String filterStatus = 'all',
    String filterDateRange = 'all',
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final hasType = selectedTypes.isNotEmpty;
    final hasStatus = filterStatus != 'all';

    return _alertRepository
        .watchMapAlertsFiltered(
          selectedTypes: selectedTypes,
          filterStatus: filterStatus,
          filterDateRange: filterDateRange,
          customStart: customStart,
          customEnd: customEnd,
        )
        .asyncMap((alerts) async {
          var filtered = alerts
              .where(
                (a) =>
                    a.shareLocation &&
                    a.location != null &&
                    _userService.canUserViewAlert(
                      a.userId,
                      a.userEmail,
                      a.isAnonymous,
                    ),
              )
              .toList();

          if (hasType) {
            final selected = selectedTypes.toSet();
            filtered = filtered
                .where((a) => selected.contains(a.alertType))
                .toList();
          }

          if (hasStatus) {
            filtered = filtered.where((a) {
              if (filterStatus == 'attended') {
                return a.alertStatus == 'attended';
              }
              return a.alertStatus != 'attended';
            }).toList();
          }

          return _access.filterByPermissionsAndCommunity(
            filtered,
            await _access.getUserCommunityAccess(),
          );
        });
  }

  Future<List<AlertModel>> getCommunityAlerts(String communityId) async {
    try {
      final filtered =
          (await _alertRepository.fetchCommunityAlerts(communityId))
              .where(
                (a) => _userService.canUserViewAlert(
                  a.userId,
                  a.userEmail,
                  a.isAnonymous,
                ),
              )
              .toList();
      final access = await _access.getUserCommunityAccess();
      return _access
          .filterByPermissionsAndCommunity(
            filtered,
            access,
          )
          .take(50)
          .toList();
    } catch (e) {
      AppLogger.e('AlertService.getCommunityAlerts', e);
      return [];
    }
  }

  Stream<List<AlertModel>> getCommunityAlertsStream(String communityId) {
    return _alertRepository.watchCommunityAlerts(communityId).asyncMap((
      alerts,
    ) async {
      final filtered =
          alerts
              .where(
                (a) => _userService.canUserViewAlert(
                  a.userId,
                  a.userEmail,
                  a.isAnonymous,
                ),
              )
              .toList();
      final access = await _access.getUserCommunityAccess();
      return _access
          .filterByPermissionsAndCommunity(
            filtered,
            access,
          )
          .take(50)
          .toList();
    });
  }

  Stream<List<AlertModel>> getMyAlertsStream() {
    final uid = _userService.currentUserId;
    final email = _userService.currentUserEmail?.trim().toLowerCase();
    return _alertRepository.watchMyAlerts(uid: uid, email: email);
  }

  Future<List<AlertModel>> getMyAlerts() async {
    final uid = _userService.currentUserId;
    final email = _userService.currentUserEmail?.trim().toLowerCase();
    return _alertRepository.fetchMyAlerts(uid: uid, email: email);
  }

  Stream<List<AlertModel>> getOwnAlertsStream(String communityId, String uid) {
    return _alertRepository.watchOwnAlertsInCommunity(communityId, uid);
  }

  Stream<List<AlertModel>> getOthersAlertsStream(
    String communityId,
    String uid,
  ) {
    return _alertRepository.watchOthersAlertsInCommunity(communityId, uid);
  }

  Future<Map<String, int>> getAlertStatistics() async {
    try {
      final alerts = await getRecentAlerts();
      final stats = <String, int>{};
      for (final alert in alerts) {
        stats[alert.alertType] = (stats[alert.alertType] ?? 0) + 1;
      }
      return stats;
    } catch (e) {
      AppLogger.e('AlertService.getAlertStatistics', e);
      return {};
    }
  }

  Future<Map<String, int>> getViewStatistics() async {
    try {
      final alerts = await getRecentAlerts();
      final stats = <String, int>{};
      for (final alert in alerts) {
        stats[alert.alertType] =
            (stats[alert.alertType] ?? 0) + alert.viewedCount;
      }
      return stats;
    } catch (e) {
      AppLogger.e('AlertService.getViewStatistics', e);
      return {};
    }
  }

  Future<Map<String, int>> getUnreadCountByCommunity() async {
    try {
      final alerts = await getRecentAlerts();
      final uid = _userService.currentUser?.uid;
      if (uid == null) return {};

      final counts = <String, int>{};
      for (final alert in alerts) {
        if (alert.communityIds.isEmpty) continue;
        if (_userService.isUserOwnerOfAlert(alert.userId, alert.userEmail)) {
          continue;
        }
        if (!alert.viewedBy.contains(uid)) {
          for (final cid in alert.communityIds) {
            counts[cid] = (counts[cid] ?? 0) + 1;
          }
        }
      }
      return counts;
    } catch (e) {
      AppLogger.e('AlertService.getUnreadCountByCommunity', e);
      return {};
    }
  }

  // ─── Mutations ───────────────────────────────────────────────────────────

  Future<void> markAlertAsViewed(String alertId) async {
    try {
      final currentUser = _userService.currentUser;
      if (currentUser == null) return;

      final alert = await _alertRepository.getAlertById(alertId);
      if (alert == null) return;

      if (_userService.isUserOwnerOfAlert(alert.userId, alert.userEmail)) {
        return;
      }

      await _alertRepository.runMarkViewedTransaction(alertId, currentUser.uid);
    } catch (e) {
      AppLogger.e('AlertService.markAlertAsViewed', e);
    }
  }

  Future<void> reportAlert(String alertId) async {
    final currentUser = _userService.currentUser;
    if (currentUser == null) throw Exception('Usuario no autenticado');
    await _alertRepository.runReportTransaction(alertId, currentUser.uid);
  }

  Future<void> updateAlertStatus(String alertId, String status) async {
    await _alertRepository.updateAlertStatus(alertId, status);
  }

  // ─── Send / forward (delegated) ──────────────────────────────────────────

  Future<bool> sendDetailedAlert({
    required String alertType,
    String? description,
    List<File>? images,
    required bool shareLocation,
    required bool isAnonymous,
  }) =>
      _send.sendDetailedAlert(
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
      _send.sendQuickAlert(
        alertType: alertType,
        isAnonymous: isAnonymous,
      );

  Future<bool> sendTypedAlert({
    required String alertType,
    required bool isAnonymous,
    required List<String> communityIds,
    String? subtype,
    String? customDetail,
    String? alertTypeLabel,
    String? alertTypeColor,
    int? alertTypeIconCodePoint,
    List<String> attachmentPlaceholders = const [],
    List<String>? imageBase64,
    String? audioBase64,
  }) =>
      _send.sendTypedAlert(
        alertType: alertType,
        isAnonymous: isAnonymous,
        communityIds: communityIds,
        subtype: subtype,
        customDetail: customDetail,
        alertTypeLabel: alertTypeLabel,
        alertTypeColor: alertTypeColor,
        alertTypeIconCodePoint: alertTypeIconCodePoint,
        attachmentPlaceholders: attachmentPlaceholders,
        imageBase64: imageBase64,
        audioBase64: audioBase64,
      );

  Future<int> forwardAlert({
    required String alertId,
    required List<String> targetCommunityIds,
  }) =>
      _send.forwardAlert(
        alertId: alertId,
        targetCommunityIds: targetCommunityIds,
      );

  Future<bool> hasLocationPermission() =>
      LocationService().hasLocationPermission();

  Future<bool> requestLocationPermission() =>
      LocationService().requestLocationPermission();
}
