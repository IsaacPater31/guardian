import 'dart:async';
import 'dart:io';

import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../models/alert_model.dart';
import '../repositories/alert_repository.dart';
import '../repositories/community_repository.dart';
import 'location_service.dart';
import 'permission_service.dart';
import 'quick_alert_config_service.dart';
import 'user_service.dart';

/// Business rules for alerts: permissions, feed visibility, sending, forwarding.
///
/// **Why a service:** composes [AlertRepository] (data) with [UserService] and
/// community membership so repositories stay free of auth/domain rules.
class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  final AlertRepository _alertRepository = AlertRepository();
  final CommunityRepository _communityRepository = CommunityRepository();
  final UserService _userService = UserService();

  List<String>? _cachedUserCommunityIds;
  Set<String>? _cachedEntityCommunityIds;
  Map<String, String>? _cachedUserRolesByCommunityId;
  DateTime? _cacheTimestamp;

  void invalidateCommunityCache() {
    _cachedUserCommunityIds = null;
    _cachedEntityCommunityIds = null;
    _cachedUserRolesByCommunityId = null;
    _cacheTimestamp = null;
  }

  Future<_UserCommunityAccess> _getUserCommunityAccess() async {
    if (_cachedUserCommunityIds != null &&
        _cachedEntityCommunityIds != null &&
        _cachedUserRolesByCommunityId != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < AppDurations.communityIdCache) {
      return _UserCommunityAccess(
        communityIds: _cachedUserCommunityIds!,
        entityCommunityIds: _cachedEntityCommunityIds!,
        rolesByCommunityId: _cachedUserRolesByCommunityId!,
      );
    }

    try {
      final uid = _userService.currentUser?.uid;
      if (uid == null) {
        return const _UserCommunityAccess(
          communityIds: [],
          entityCommunityIds: <String>{},
          rolesByCommunityId: <String, String>{},
        );
      }

      final communities = await _communityRepository.fetchUserCommunities(uid);
      _cachedUserCommunityIds = communities.map((c) => c['id'] as String).toList();
      _cachedEntityCommunityIds = communities
          .where((c) => (c[CommunityFields.isEntity] as bool? ?? false))
          .map((c) => c['id'] as String)
          .toSet();

      final memberships = await _communityRepository.queryMembershipsForUser(uid);
      _cachedUserRolesByCommunityId = {
        for (final doc in memberships.docs)
          (doc.data()[MemberFields.communityId] as String):
              (doc.data()[MemberFields.role] as String? ?? MemberFields.roleMember),
      };

      _cacheTimestamp = DateTime.now();
      return _UserCommunityAccess(
        communityIds: _cachedUserCommunityIds!,
        entityCommunityIds: _cachedEntityCommunityIds!,
        rolesByCommunityId: _cachedUserRolesByCommunityId!,
      );
    } catch (e) {
      AppLogger.e('AlertService._getUserCommunityAccess', e);
      return _UserCommunityAccess(
        communityIds: _cachedUserCommunityIds ?? const [],
        entityCommunityIds: _cachedEntityCommunityIds ?? const {},
        rolesByCommunityId: _cachedUserRolesByCommunityId ?? const {},
      );
    }
  }

  List<AlertModel> _filterByPermissionsAndCommunity(
    List<AlertModel> alerts,
    _UserCommunityAccess access,
  ) {
    final uid = _userService.currentUser?.uid;
    final membershipSet = access.communityIds.toSet();

    return alerts.where((alert) {
      if (!_userService.canUserViewAlert(alert.userId, alert.userEmail, alert.isAnonymous)) {
        return false;
      }
      if (alert.communityIds.isEmpty) return true;

      for (final communityId in alert.communityIds) {
        if (!membershipSet.contains(communityId)) continue;

        final isEntity = access.entityCommunityIds.contains(communityId);
        if (!isEntity) return true;

        final role = access.rolesByCommunityId[communityId] ?? MemberFields.roleMember;
        if (role == MemberFields.roleOfficial || role == MemberFields.roleAdmin) {
          return true;
        }
        if (uid != null && alert.userId == uid) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  // ─── Reads ───────────────────────────────────────────────────────────────

  Future<List<AlertModel>> getRecentAlerts() async {
    try {
      final since = DateTime.now().subtract(AppDurations.alertFeedWindow);
      final raw = await _alertRepository.fetchRecentAlertsSince(since);
      return _filterByPermissionsAndCommunity(raw, await _getUserCommunityAccess());
    } catch (e) {
      AppLogger.e('AlertService.getRecentAlerts', e);
      return [];
    }
  }

  Stream<List<AlertModel>> getRecentAlertsStream() {
    final since = DateTime.now().subtract(AppDurations.alertFeedWindow);
    return _alertRepository.watchRecentAlertsSince(since).asyncMap((snapshot) async {
      final raw = snapshot.docs.map(AlertModel.fromFirestore).toList();
      return _filterByPermissionsAndCommunity(raw, await _getUserCommunityAccess());
    });
  }

  Future<List<AlertModel>> getMapAlerts() async {
    try {
      final since = DateTime.now().subtract(AppDurations.mapAlertsWindow);
      final raw = await _alertRepository.fetchMapAlertsSince(since);
      final visible = raw.where((a) {
        if (!a.shareLocation || a.location == null) return false;
        return _userService.canUserViewAlert(a.userId, a.userEmail, a.isAnonymous);
      }).toList();
      return _filterByPermissionsAndCommunity(visible, await _getUserCommunityAccess());
    } catch (e) {
      AppLogger.e('AlertService.getMapAlerts', e);
      return [];
    }
  }

  Stream<List<AlertModel>> getMapAlertsStream() {
    final since = DateTime.now().subtract(AppDurations.mapAlertsWindow);
    return _alertRepository.watchMapAlertsSince(since).asyncMap((snapshot) async {
      final visible = snapshot.docs
          .map(AlertModel.fromFirestore)
          .where((a) =>
              a.shareLocation &&
              a.location != null &&
              _userService.canUserViewAlert(a.userId, a.userEmail, a.isAnonymous))
          .toList();
      return _filterByPermissionsAndCommunity(visible, await _getUserCommunityAccess());
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
        .asyncMap((snapshot) async {
      var alerts = snapshot.docs.map(AlertModel.fromFirestore).toList();

      alerts = alerts
          .where((a) =>
              a.shareLocation &&
              a.location != null &&
              _userService.canUserViewAlert(a.userId, a.userEmail, a.isAnonymous))
          .toList();

      if (hasType && selectedTypes.length > 1) {
        alerts = alerts.where((a) => selectedTypes.contains(a.alertType)).toList();
      }

      if (hasStatus) {
        alerts = alerts.where((a) {
          if (filterStatus == 'attended') return a.alertStatus == 'attended';
          return a.alertStatus != 'attended';
        }).toList();
      }

      return _filterByPermissionsAndCommunity(alerts, await _getUserCommunityAccess());
    });
  }

  Future<List<AlertModel>> getCommunityAlerts(String communityId) async {
    try {
      final filtered = (await _alertRepository.fetchCommunityAlerts(communityId))
          .where((a) => _userService.canUserViewAlert(a.userId, a.userEmail, a.isAnonymous))
          .toList();
      final access = await _getUserCommunityAccess();
      return _filterByPermissionsAndCommunity(filtered, access).take(50).toList();
    } catch (e) {
      AppLogger.e('AlertService.getCommunityAlerts', e);
      return [];
    }
  }

  Stream<List<AlertModel>> getCommunityAlertsStream(String communityId) {
    return _alertRepository.watchCommunityAlerts(communityId).asyncMap((snapshot) async {
      final filtered = snapshot.docs
          .map(AlertModel.fromFirestore)
          .where((a) => _userService.canUserViewAlert(a.userId, a.userEmail, a.isAnonymous))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final access = await _getUserCommunityAccess();
      return _filterByPermissionsAndCommunity(filtered, access).take(50).toList();
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

  Stream<List<AlertModel>> getOthersAlertsStream(String communityId, String uid) {
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
        stats[alert.alertType] = (stats[alert.alertType] ?? 0) + alert.viewedCount;
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

      final snap = await _alertRepository.getAlertDocument(alertId);
      if (!snap.exists) return;

      final ownerId = snap.data()?[AlertFields.userId] as String?;
      final ownerEmail = snap.data()?[AlertFields.userEmail] as String?;
      if (_userService.isUserOwnerOfAlert(ownerId, ownerEmail)) {
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

  // ─── Send / forward use cases ────────────────────────────────────────────

  Future<bool> sendDetailedAlert({
    required String alertType,
    String? description,
    List<File>? images,
    required bool shareLocation,
    required bool isAnonymous,
  }) async {
    try {
      if (!_userService.canUserSendAlerts()) {
        throw Exception('Usuario no autenticado');
      }

      LocationData? locationData;
      if (shareLocation) {
        final hasPermission = await PermissionService.requestLocationPermissionForAlerts();
        if (!hasPermission) {
          throw Exception('Permisos de ubicación requeridos para enviar alertas con ubicación');
        }
        locationData = await LocationService().getCurrentLocation();
        if (locationData == null) throw Exception('No se pudo obtener la ubicación');
      }

      final userInfo = _userService.getUserInfoForAlert();
      final userName = _userService.getUserDisplayName(isAnonymous: isAnonymous);

      final alert = AlertModel(
        type: 'detailed',
        alertType: alertType,
        description: description,
        timestamp: DateTime.now(),
        isAnonymous: isAnonymous,
        shareLocation: shareLocation,
        location: locationData,
        userId: userInfo['userId'],
        userEmail: userInfo['userEmail'],
        userName: userName,
        viewedCount: 0,
        viewedBy: [],
        communityIds: const [],
      );

      await _alertRepository.saveAlert(alert);
      return true;
    } catch (e) {
      AppLogger.e('AlertService.sendDetailedAlert', e);
      return false;
    }
  }

  Future<bool> sendQuickAlert({
    required String alertType,
    required bool isAnonymous,
  }) async {
    try {
      if (!_userService.canUserSendAlerts()) {
        throw Exception('Usuario no autenticado');
      }

      final hasPermission = await PermissionService.requestLocationPermissionForAlerts();
      if (!hasPermission) {
        throw Exception('Permisos de ubicación requeridos para alertas rápidas');
      }

      final locationData = await LocationService().getCurrentLocation();
      if (locationData == null) throw Exception('No se pudo obtener la ubicación');

      final userInfo = _userService.getUserInfoForAlert();
      final userName = _userService.getUserDisplayName(isAnonymous: isAnonymous);

      final destinations = await QuickAlertConfigService().getQuickAlertDestinations();
      if (destinations.isEmpty) {
        throw Exception('No hay destinos configurados para quick alerts');
      }

      final alert = AlertModel(
        type: 'quick',
        alertType: alertType,
        timestamp: DateTime.now(),
        isAnonymous: isAnonymous,
        shareLocation: true,
        location: locationData,
        userId: userInfo['userId'],
        userEmail: userInfo['userEmail'],
        userName: userName,
        viewedCount: 0,
        viewedBy: [],
        communityIds: destinations,
        forwardsCount: 0,
        reportsCount: 0,
      );

      await _alertRepository.saveAlert(alert);
      AppLogger.d('Quick alert sent to ${destinations.length} communities in 1 document');
      return true;
    } catch (e) {
      AppLogger.e('AlertService.sendQuickAlert', e);
      return false;
    }
  }

  Future<bool> sendSwipedAlert({
    required String alertType,
    required bool isAnonymous,
    required List<String> communityIds,
    String? subtype,
    String? customDetail,
    List<String> attachmentPlaceholders = const [],
  }) async {
    try {
      if (!_userService.canUserSendAlerts()) {
        throw Exception('Usuario no autenticado');
      }

      final hasPermission = await PermissionService.requestLocationPermissionForAlerts();
      if (!hasPermission) {
        throw Exception('Permisos de ubicación requeridos para alertas deslizadas');
      }

      final locationData = await LocationService().getCurrentLocation();
      if (locationData == null) throw Exception('No se pudo obtener la ubicación');

      final userInfo = _userService.getUserInfoForAlert();
      final userName = _userService.getUserDisplayName(isAnonymous: isAnonymous);

      final alert = AlertModel(
        type: 'swiped',
        alertType: alertType,
        subtype: subtype,
        customDetail: customDetail,
        timestamp: DateTime.now(),
        isAnonymous: isAnonymous,
        shareLocation: true,
        location: locationData,
        userId: userInfo['userId'],
        userEmail: userInfo['userEmail'],
        userName: userName,
        viewedCount: 0,
        viewedBy: [],
        communityIds: communityIds,
        attachmentPlaceholders: attachmentPlaceholders,
        forwardsCount: 0,
        reportsCount: 0,
      );

      await _alertRepository.saveAlert(alert);
      AppLogger.d('Swiped alert sent to ${communityIds.length} communities in 1 document');
      return true;
    } catch (e) {
      AppLogger.e('AlertService.sendSwipedAlert', e);
      return false;
    }
  }

  Future<int> forwardAlert({
    required String alertId,
    required List<String> targetCommunityIds,
  }) async {
    if (targetCommunityIds.isEmpty) {
      throw Exception('Debe seleccionar al menos una comunidad destino');
    }

    if (!_userService.canUserSendAlerts()) {
      throw Exception('Usuario no autenticado');
    }

    final alertDoc = await _alertRepository.getAlertDocument(alertId);
    if (!alertDoc.exists) throw Exception('Alerta no encontrada');

    final originalAlert = AlertModel.fromFirestore(alertDoc);

    if (originalAlert.communityIds.isNotEmpty) {
      final originCommunity =
          await _communityRepository.getCommunityById(originalAlert.communityIds.first);

      if (originCommunity != null && !originCommunity.allowForwardToEntities) {
        final userId = _userService.currentUserId;
        if (userId == null) throw Exception('Usuario no autenticado');

        final allCommunities = await _communityRepository.fetchUserCommunities(userId);
        final targets = allCommunities
            .where((c) => targetCommunityIds.contains(c['id'] as String))
            .toList();

        if (targets.any((c) => c[CommunityFields.isEntity] == true)) {
          throw Exception('Esta comunidad no permite reenviar alertas a entidades');
        }
      }
    }

    final userInfo = _userService.getUserInfoForAlert();
    final userName = _userService.getUserDisplayName(isAnonymous: false);

    final timestamp = DateTime.now();
    final forwardedAlerts = <AlertModel>[];

    for (final targetCommunityId in targetCommunityIds) {
      if (originalAlert.communityIds.contains(targetCommunityId)) {
        AppLogger.d('Skipping duplicate community: $targetCommunityId');
        continue;
      }

      forwardedAlerts.add(
        AlertModel(
          type: originalAlert.type,
          alertType: originalAlert.alertType,
          description: originalAlert.description,
          timestamp: timestamp,
          isAnonymous: false,
          shareLocation: originalAlert.shareLocation,
          location: originalAlert.location,
          userId: userInfo['userId'],
          userEmail: userInfo['userEmail'],
          userName: userName,
          viewedCount: 0,
          viewedBy: [],
          communityIds: [targetCommunityId],
          forwardsCount: 0,
          reportsCount: 0,
          imageBase64: originalAlert.imageBase64,
          subtype: originalAlert.subtype,
          customDetail: originalAlert.customDetail,
          attachmentPlaceholders: originalAlert.attachmentPlaceholders,
        ),
      );
    }

    if (forwardedAlerts.isEmpty) {
      throw Exception('Todas las comunidades seleccionadas ya tienen esta alerta');
    }

    final count = await _alertRepository.commitForwardBatch(
      originalAlertId: alertId,
      forwardedAlerts: forwardedAlerts,
      previousForwardsCount: originalAlert.forwardsCount,
    );

    AppLogger.d('Alert forwarded to $count communities');
    return count;
  }

  Future<bool> hasLocationPermission() => LocationService().hasLocationPermission();

  Future<bool> requestLocationPermission() => LocationService().requestLocationPermission();
}

class _UserCommunityAccess {
  final List<String> communityIds;
  final Set<String> entityCommunityIds;
  final Map<String, String> rolesByCommunityId;

  const _UserCommunityAccess({
    required this.communityIds,
    required this.entityCommunityIds,
    required this.rolesByCommunityId,
  });
}
