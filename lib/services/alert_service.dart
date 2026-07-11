import 'dart:async';
import 'dart:io';

import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../core/community_visibility.dart';
import '../models/alert_model.dart';
import '../models/community_model.dart';
import '../repositories/alert_repository.dart';
import '../repositories/community_repository.dart';
import 'location_service.dart';
import 'permission_service.dart';
import 'quick_alert_config_service.dart';
import 'alert_fanout_service.dart';
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
  final AlertFanoutService _alertFanoutService = AlertFanoutService();

  List<String>? _cachedUserCommunityIds;
  Map<String, String>? _cachedUserRolesByCommunityId;
  DateTime? _cacheTimestamp;

  void invalidateCommunityCache() {
    _cachedUserCommunityIds = null;
    _cachedUserRolesByCommunityId = null;
    _cacheTimestamp = null;
  }

  Future<_UserCommunityAccess> _getUserCommunityAccess() async {
    if (_cachedUserCommunityIds != null &&
        _cachedUserRolesByCommunityId != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) <
            AppDurations.communityIdCache) {
      return _UserCommunityAccess(
        communityIds: _cachedUserCommunityIds!,
        rolesByCommunityId: _cachedUserRolesByCommunityId!,
      );
    }

    try {
      final uid = _userService.currentUser?.uid;
      if (uid == null) {
        return const _UserCommunityAccess(
          communityIds: [],
          rolesByCommunityId: <String, String>{},
        );
      }

      final communities = await _communityRepository.fetchUserCommunities(uid);

      final memberships = await _communityRepository.queryMembershipsForUser(
        uid,
      );
      _cachedUserRolesByCommunityId = {
        for (final doc in memberships.docs)
          (doc.data()[MemberFields.communityId] as String):
              (doc.data()[MemberFields.role] as String? ??
              MemberFields.roleMember),
      };

      // Comunidades cuyas alertas puede VER el usuario en sus feeds:
      // - normales: cualquier miembro;
      // - entidades: solo official (los reportes de otros ciudadanos
      //   no deben llegarle a miembros rasos ni a roles legacy de admin).
      _cachedUserCommunityIds = communities
          .where((c) {
            if (!communityMapIsEntity(c)) return true;
            final role = _cachedUserRolesByCommunityId![c['id'] as String];
            return role == MemberFields.roleOfficial;
          })
          .map((c) => c['id'] as String)
          .toList();

      _cacheTimestamp = DateTime.now();
      return _UserCommunityAccess(
        communityIds: _cachedUserCommunityIds!,
        rolesByCommunityId: _cachedUserRolesByCommunityId!,
      );
    } catch (e) {
      AppLogger.e('AlertService._getUserCommunityAccess', e);
      return _UserCommunityAccess(
        communityIds: _cachedUserCommunityIds ?? const [],
        rolesByCommunityId: _cachedUserRolesByCommunityId ?? const {},
      );
    }
  }

  List<AlertModel> _filterByPermissionsAndCommunity(
    List<AlertModel> alerts,
    _UserCommunityAccess access,
  ) {
    final membershipSet = access.communityIds.toSet();

    return alerts.where((alert) {
      if (!_userService.canUserViewAlert(
        alert.userId,
        alert.userEmail,
        alert.isAnonymous,
      )) {
        return false;
      }
      if (alert.communityIds.isEmpty) return true;

      // El emisor siempre ve sus propias alertas/reportes (p. ej. un ciudadano
      // que reportó a una entidad puede seguir el estado aunque no reciba
      // los reportes de otros).
      if (_userService.isUserOwnerOfAlert(alert.userId, alert.userEmail)) {
        return true;
      }

      return alert.communityIds.any(membershipSet.contains);
    }).toList();
  }

  // ─── Reads ───────────────────────────────────────────────────────────────

  Future<List<AlertModel>> getRecentAlerts() async {
    try {
      final since = DateTime.now().subtract(AppDurations.alertFeedWindow);
      final raw = await _alertRepository.fetchRecentAlertsSince(since);
      return _filterByPermissionsAndCommunity(
        raw,
        await _getUserCommunityAccess(),
      );
    } catch (e) {
      AppLogger.e('AlertService.getRecentAlerts', e);
      return [];
    }
  }

  Stream<List<AlertModel>> getRecentAlertsStream() {
    final since = DateTime.now().subtract(AppDurations.alertFeedWindow);
    return _alertRepository.watchRecentAlertsSince(since).asyncMap((
      snapshot,
    ) async {
      final raw = snapshot.docs.map(AlertModel.fromFirestore).toList();
      return _filterByPermissionsAndCommunity(
        raw,
        await _getUserCommunityAccess(),
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
      return _filterByPermissionsAndCommunity(
        visible,
        await _getUserCommunityAccess(),
      );
    } catch (e) {
      AppLogger.e('AlertService.getMapAlerts', e);
      return [];
    }
  }

  Stream<List<AlertModel>> getMapAlertsStream() {
    final since = DateTime.now().subtract(AppDurations.mapAlertsWindow);
    return _alertRepository.watchMapAlertsSince(since).asyncMap((
      snapshot,
    ) async {
      final visible = snapshot.docs
          .map(AlertModel.fromFirestore)
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
      return _filterByPermissionsAndCommunity(
        visible,
        await _getUserCommunityAccess(),
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
        .asyncMap((snapshot) async {
          var alerts = snapshot.docs.map(AlertModel.fromFirestore).toList();

          alerts = alerts
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
            alerts = alerts
                .where((a) => selected.contains(a.alertType))
                .toList();
          }

          if (hasStatus) {
            alerts = alerts.where((a) {
              if (filterStatus == 'attended') {
                return a.alertStatus == 'attended';
              }
              return a.alertStatus != 'attended';
            }).toList();
          }

          return _filterByPermissionsAndCommunity(
            alerts,
            await _getUserCommunityAccess(),
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
      final access = await _getUserCommunityAccess();
      return _filterByPermissionsAndCommunity(
        filtered,
        access,
      ).take(50).toList();
    } catch (e) {
      AppLogger.e('AlertService.getCommunityAlerts', e);
      return [];
    }
  }

  Stream<List<AlertModel>> getCommunityAlertsStream(String communityId) {
    return _alertRepository.watchCommunityAlerts(communityId).asyncMap((
      snapshot,
    ) async {
      final filtered =
          snapshot.docs
              .map(AlertModel.fromFirestore)
              .where(
                (a) => _userService.canUserViewAlert(
                  a.userId,
                  a.userEmail,
                  a.isAnonymous,
                ),
              )
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final access = await _getUserCommunityAccess();
      return _filterByPermissionsAndCommunity(
        filtered,
        access,
      ).take(50).toList();
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
        final hasPermission =
            await PermissionService.requestLocationPermissionForAlerts();
        if (!hasPermission) {
          throw Exception(
            'Permisos de ubicación requeridos para enviar alertas con ubicación',
          );
        }
        locationData = await LocationService().getCurrentLocation();
        if (locationData == null) {
          throw Exception('No se pudo obtener la ubicación');
        }
      }

      final userInfo = _userService.getUserInfoForAlert();
      final userName = _userService.getUserDisplayName(
        isAnonymous: isAnonymous,
      );

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

      await _saveAlertWithFanout(alert);
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

      final hasPermission =
          await PermissionService.requestLocationPermissionForAlerts();
      if (!hasPermission) {
        throw Exception(
          'Permisos de ubicación requeridos para alertas rápidas',
        );
      }

      final locationData = await LocationService().getCurrentLocation();
      if (locationData == null) {
        throw Exception('No se pudo obtener la ubicación');
      }

      final userInfo = _userService.getUserInfoForAlert();
      final userName = _userService.getUserDisplayName(
        isAnonymous: isAnonymous,
      );

      final destinations = await QuickAlertConfigService()
          .getQuickAlertDestinations();
      if (destinations.isEmpty) {
        throw Exception('No hay destinos configurados para alerta de urgencia');
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

      await _saveAlertWithFanout(alert);
      AppLogger.d(
        'Quick alert sent to ${destinations.length} communities in 1 document',
      );
      return true;
    } catch (e) {
      AppLogger.e('AlertService.sendQuickAlert', e);
      return false;
    }
  }

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
  }) async {
    try {
      if (!_userService.canUserSendAlerts()) {
        throw Exception('Usuario no autenticado');
      }

      await _assertValidAlertCommunityDestinations(
        communityIds,
        alertType: alertType,
      );

      final hasPermission =
          await PermissionService.requestLocationPermissionForAlerts();
      if (!hasPermission) {
        throw Exception('Permisos de ubicación requeridos para enviar alertas');
      }

      final locationData = await LocationService().getCurrentLocation();
      if (locationData == null) {
        throw Exception('No se pudo obtener la ubicación');
      }

      final userInfo = _userService.getUserInfoForAlert();
      final userName = _userService.getUserDisplayName(
        isAnonymous: isAnonymous,
      );

      final alert = AlertModel(
        type: 'typed',
        alertType: alertType,
        alertTypeLabel: alertTypeLabel,
        alertTypeColor: alertTypeColor,
        alertTypeIconCodePoint: alertTypeIconCodePoint,
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
        imageBase64: imageBase64,
        audioBase64: audioBase64,
        forwardsCount: 0,
        reportsCount: 0,
      );

      await _saveAlertWithFanout(alert);
      AppLogger.d(
        'Typed alert sent to ${communityIds.length} communities in 1 document',
      );
      return true;
    } catch (e) {
      AppLogger.e('AlertService.sendTypedAlert', e);
      return false;
    }
  }

  @Deprecated('Use sendTypedAlert')
  Future<bool> sendSwipedAlert({
    required String alertType,
    required bool isAnonymous,
    required List<String> communityIds,
    String? subtype,
    String? customDetail,
    List<String> attachmentPlaceholders = const [],
    List<String>? imageBase64,
    String? audioBase64,
  }) => sendTypedAlert(
    alertType: alertType,
    isAnonymous: isAnonymous,
    communityIds: communityIds,
    subtype: subtype,
    customDetail: customDetail,
    attachmentPlaceholders: attachmentPlaceholders,
    imageBase64: imageBase64,
    audioBase64: audioBase64,
  );

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

    final userInfo = _userService.getUserInfoForAlert();
    final userName = _userService.getUserDisplayName(isAnonymous: false);

    final timestamp = DateTime.now();
    final forwardedAlerts = <AlertModel>[];

    for (final targetCommunityId in targetCommunityIds) {
      if (originalAlert.communityIds.contains(targetCommunityId)) {
        AppLogger.d('Skipping duplicate community: $targetCommunityId');
        continue;
      }

      await _assertValidAlertCommunityDestinations([targetCommunityId]);

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
          audioBase64: originalAlert.audioBase64,
          subtype: originalAlert.subtype,
          customDetail: originalAlert.customDetail,
          attachmentPlaceholders: originalAlert.attachmentPlaceholders,
        ),
      );
    }

    if (forwardedAlerts.isEmpty) {
      throw Exception(
        'Todas las comunidades seleccionadas ya tienen esta alerta',
      );
    }

    final created = await _alertRepository.commitForwardBatch(
      originalAlertId: alertId,
      forwardedAlerts: forwardedAlerts,
      previousForwardsCount: originalAlert.forwardsCount,
    );

    for (final item in created) {
      await _alertFanoutService.fanoutAlert(item.id, item.alert);
    }

    AppLogger.d('Alert forwarded to ${created.length} communities');
    return created.length;
  }

  Future<void> _saveAlertWithFanout(AlertModel alert) async {
    final alertId = await _alertRepository.saveAlert(alert);
    await _alertFanoutService.fanoutAlert(alertId, alert);
  }

  /// Un reporte a entidad va **solo** a esa entidad (un id). Las alertas
  /// normales no pueden incluir entidades en `community_ids`.
  Future<void> _assertValidAlertCommunityDestinations(
    List<String> communityIds, {
    String? alertType,
  }) async {
    if (communityIds.isEmpty) return;

    var entityCount = 0;
    var normalCount = 0;
    CommunityModel? soleEntity;

    for (final id in communityIds) {
      final community = await _communityRepository.getCommunityById(id);
      if (community == null) {
        throw Exception('Comunidad no encontrada');
      }
      if (community.isEntity) {
        entityCount++;
        soleEntity = community;
      } else {
        normalCount++;
      }
    }

    if (entityCount > 0 && normalCount > 0) {
      throw Exception(
        'Un reporte a entidad no puede enviarse junto con comunidades normales',
      );
    }
    if (entityCount > 1) {
      throw Exception('Un reporte solo puede enviarse a una entidad');
    }

    if (soleEntity != null && alertType != null) {
      if (soleEntity.reportAlertTypes.isEmpty) {
        throw Exception(
          'Esta entidad no tiene tipos de reporte configurados',
        );
      }
      if (!soleEntity.reportAlertTypes.any((t) => t.id == alertType)) {
        throw Exception(
          'Este tipo de reporte no está habilitado para la entidad',
        );
      }
    }
  }

  Future<bool> hasLocationPermission() =>
      LocationService().hasLocationPermission();

  Future<bool> requestLocationPermission() =>
      LocationService().requestLocationPermission();
}

class _UserCommunityAccess {
  final List<String> communityIds;
  final Map<String, String> rolesByCommunityId;

  const _UserCommunityAccess({
    required this.communityIds,
    required this.rolesByCommunityId,
  });
}
