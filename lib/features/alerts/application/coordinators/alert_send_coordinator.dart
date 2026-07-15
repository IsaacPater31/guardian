import 'dart:io';

import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/alerts/domain/alert_model.dart';
import 'package:guardian/features/communities/domain/community_model.dart';
import 'package:guardian/features/alerts/data/alert_repository.dart';
import 'package:guardian/features/communities/data/community_repository.dart';
import 'package:guardian/features/alerts/application/alert_fanout_service.dart';
import 'package:guardian/features/home_shell/application/location_service.dart';
import 'package:guardian/features/home_shell/application/permission_service.dart';
import 'package:guardian/features/settings/application/quick_alert_config_service.dart';
import 'package:guardian/features/auth/application/user_service.dart';

/// Coordinates alert send / forward use cases (location, destinations, fan-out).
class AlertSendCoordinator {
  final AlertRepository _alertRepository;
  final CommunityRepository _communityRepository;
  final UserService _userService;
  final AlertFanoutService _alertFanoutService;
  final QuickAlertConfigService _quickAlertConfigService;
  final LocationService _locationService;

  AlertSendCoordinator({
    AlertRepository? alertRepository,
    CommunityRepository? communityRepository,
    UserService? userService,
    AlertFanoutService? alertFanoutService,
    QuickAlertConfigService? quickAlertConfigService,
    LocationService? locationService,
  })  : _alertRepository = alertRepository ?? AlertRepository(),
        _communityRepository = communityRepository ?? CommunityRepository(),
        _userService = userService ?? UserService(),
        _alertFanoutService = alertFanoutService ?? AlertFanoutService(),
        _quickAlertConfigService =
            quickAlertConfigService ?? QuickAlertConfigService(),
        _locationService = locationService ?? LocationService();

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
        locationData = await _locationService.getCurrentLocation();
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
      AppLogger.e('AlertSendCoordinator.sendDetailedAlert', e);
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

      final locationData = await _locationService.getCurrentLocation();
      if (locationData == null) {
        throw Exception('No se pudo obtener la ubicación');
      }

      final userInfo = _userService.getUserInfoForAlert();
      final userName = _userService.getUserDisplayName(
        isAnonymous: isAnonymous,
      );

      final destinations =
          await _quickAlertConfigService.getQuickAlertDestinations();
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
      AppLogger.e('AlertSendCoordinator.sendQuickAlert', e);
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

      final locationData = await _locationService.getCurrentLocation();
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
      AppLogger.e('AlertSendCoordinator.sendTypedAlert', e);
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

    final originalAlert = await _alertRepository.getAlertById(alertId);
    if (originalAlert == null) throw Exception('Alerta no encontrada');

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
}
