import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../models/alert_model.dart';
import '../services/alert_repository.dart';
import '../services/location_service.dart';
import '../services/image_service.dart';
import '../services/user_service.dart';
import '../services/permission_service.dart';
import '../services/quick_alert_config_service.dart';
import '../services/community_service.dart';
import '../services/community_repository.dart';

/// Orchestrates the sending and forwarding of alerts.
///
/// This controller acts as the application-level boundary between the UI and
/// the data/service layer. It focuses on use-case logic (permissions, location,
/// batch writing) and delegates persistence to [AlertRepository].
class AlertController {
  final AlertRepository _alertRepository = AlertRepository();
  final LocationService _locationService = LocationService();
  final ImageService _imageService = ImageService();
  final UserService _userService = UserService();

  // ─── Send methods ─────────────────────────────────────────────────────────

  /// Sends a detailed alert (with optional description and image).
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
        locationData = await _locationService.getCurrentLocation();
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
        userId: !isAnonymous ? userInfo['userId'] : null,
        userEmail: !isAnonymous ? userInfo['userEmail'] : null,
        userName: userName,
        viewedCount: 0,
        viewedBy: [],
        communityIds: const [], // detailed alerts have no community unless sent via community UI
      );

      final alertId = await _alertRepository.saveAlert(alert);

      if (images != null && images.isNotEmpty) {
        await _imageService.convertImageToBase64AndUpdateAlert(
          images.first,
          FirebaseFirestore.instance
              .collection(FirestoreCollections.alerts)
              .doc(alertId),
        );
      }

      return true;
    } catch (e) {
      AppLogger.e('AlertController.sendDetailedAlert', e);
      return false;
    }
  }

  /// Sends a quick alert to all configured destinations simultaneously.
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
        throw Exception('Permisos de ubicación requeridos para enviar alertas rápidas');
      }

      final locationData = await _locationService.getCurrentLocation();
      if (locationData == null) throw Exception('No se pudo obtener la ubicación');

      final userInfo = _userService.getUserInfoForAlert();
      final userName = _userService.getUserDisplayName(isAnonymous: isAnonymous);

      final destinations = await QuickAlertConfigService().getQuickAlertDestinations();
      if (destinations.isEmpty) {
        throw Exception('No hay destinos configurados para quick alerts');
      }

      // ── ONE document, multiple communities ────────────────────────────────
      // Instead of creating N separate documents (old pattern),
      // we save a single alert with communityIds = all destination IDs.
      final alert = AlertModel(
        type: 'quick',
        alertType: alertType,
        timestamp: DateTime.now(),
        isAnonymous: isAnonymous,
        shareLocation: true,
        location: locationData,
        userId: !isAnonymous ? userInfo['userId'] : null,
        userEmail: !isAnonymous ? userInfo['userEmail'] : null,
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
      AppLogger.e('AlertController.sendQuickAlert', e);
      return false;
    }
  }

  /// Sends a swiped (radial-menu) alert to a single [communityId].
  Future<bool> sendSwipedAlert({
    required String alertType,
    required bool isAnonymous,
    required String communityId,
  }) async {
    try {
      if (!_userService.canUserSendAlerts()) {
        throw Exception('Usuario no autenticado');
      }

      final hasPermission = await PermissionService.requestLocationPermissionForAlerts();
      if (!hasPermission) {
        throw Exception('Permisos de ubicación requeridos para enviar alertas deslizadas');
      }

      final locationData = await _locationService.getCurrentLocation();
      if (locationData == null) throw Exception('No se pudo obtener la ubicación');

      final userInfo = _userService.getUserInfoForAlert();
      final userName = _userService.getUserDisplayName(isAnonymous: isAnonymous);

      final alert = AlertModel(
        type: 'swiped',
        alertType: alertType,
        timestamp: DateTime.now(),
        isAnonymous: isAnonymous,
        shareLocation: true,
        location: locationData,
        userId: !isAnonymous ? userInfo['userId'] : null,
        userEmail: !isAnonymous ? userInfo['userEmail'] : null,
        userName: userName,
        viewedCount: 0,
        viewedBy: [],
        communityIds: [communityId],
        forwardsCount: 0,
        reportsCount: 0,
      );

      await _alertRepository.saveAlert(alert);
      return true;
    } catch (e) {
      AppLogger.e('AlertController.sendSwipedAlert', e);
      return false;
    }
  }

  // ─── Forwarding ───────────────────────────────────────────────────────────

  /// Forwards [alertId] to each community in [targetCommunityIds].
  ///
  /// Returns the number of communities to which the alert was successfully
  /// forwarded. Throws if the originating community prohibits forwarding to
  /// entities and any target is an entity.
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

    final alertDoc = await FirebaseFirestore.instance
        .collection(FirestoreCollections.alerts)
        .doc(alertId)
        .get();

    if (!alertDoc.exists) throw Exception('Alerta no encontrada');

    final originalAlert = AlertModel.fromFirestore(alertDoc);

    if (originalAlert.communityId != null && originalAlert.communityId!.isNotEmpty) {
      final originCommunity =
          await CommunityRepository().getCommunityById(originalAlert.communityId!);

      if (originCommunity != null && !originCommunity.allowForwardToEntities) {
        final allCommunities = await CommunityService().getMyCommunities();
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

    final batch = FirebaseFirestore.instance.batch();
    final timestamp = DateTime.now();
    var successCount = 0;

    for (final targetCommunityId in targetCommunityIds) {
      // Skip communities already in the original alert's communityIds
      if (originalAlert.communityIds.contains(targetCommunityId)) {
        AppLogger.d('Skipping duplicate community: $targetCommunityId');
        continue;
      }

      final forwarded = AlertModel(
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
      );

      final ref = FirebaseFirestore.instance
          .collection(FirestoreCollections.alerts)
          .doc();
      batch.set(ref, forwarded.toFirestore());
      successCount++;
    }

    if (successCount == 0) {
      throw Exception('Todas las comunidades seleccionadas ya tienen esta alerta');
    }

    batch.update(
      FirebaseFirestore.instance
          .collection(FirestoreCollections.alerts)
          .doc(alertId),
      {AlertFields.forwardsCount: originalAlert.forwardsCount + successCount},
    );

    await batch.commit();
    AppLogger.d('Alert forwarded to $successCount communities');
    return successCount;
  }

  // ─── Utility delegates ────────────────────────────────────────────────────

  /// Records the current user as a viewer of [alertId].
  Future<void> markAlertAsViewed(String alertId) async {
    try {
      await _alertRepository.markAlertAsViewed(alertId);
    } catch (e) {
      AppLogger.e('AlertController.markAlertAsViewed', e);
    }
  }

  /// Reports [alertId]. Throws on error.
  Future<void> reportAlert(String alertId) async {
    await _alertRepository.reportAlert(alertId);
  }

  /// Returns `true` if the user has granted location permissions.
  Future<bool> hasLocationPermission() =>
      _locationService.hasLocationPermission();

  /// Requests location permissions and returns the result.
  Future<bool> requestLocationPermission() =>
      _locationService.requestLocationPermission();
}