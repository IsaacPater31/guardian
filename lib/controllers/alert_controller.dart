import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';
import '../services/alert_repository.dart';
import '../services/location_service.dart';
import '../services/image_service.dart';
import '../services/user_service.dart';
import '../services/permission_service.dart';
import '../services/quick_alert_config_service.dart';
import '../services/community_service.dart';
import '../services/community_repository.dart';

class AlertController {
  final AlertRepository _alertRepository = AlertRepository();
  final LocationService _locationService = LocationService();
  final ImageService _imageService = ImageService();
  final UserService _userService = UserService();

  /// Envía una alerta detallada a Firebase
  /// [alertType] - Tipo de alerta (ej: "Robo", "Accidente", etc.)
  /// [description] - Descripción opcional de la alerta
  /// [images] - Lista de imágenes opcionales
  /// [shareLocation] - Si se debe incluir ubicación
  /// [isAnonymous] - Si la alerta debe ser anónima
  Future<bool> sendDetailedAlert({
    required String alertType,
    String? description,
    List<File>? images,
    required bool shareLocation,
    required bool isAnonymous,
  }) async {
    try {
      // Verificar que el usuario puede enviar alertas
      if (!_userService.canUserSendAlerts()) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener ubicación si es requerida
      LocationData? locationData;
      if (shareLocation) {
        // Solicitar permisos de ubicación si es necesario
        final hasLocationPermission = await PermissionService.requestLocationPermissionForAlerts();
        if (!hasLocationPermission) {
          throw Exception('Permisos de ubicación requeridos para enviar alertas con ubicación');
        }
        
        locationData = await _locationService.getCurrentLocation();
        if (locationData == null) {
          throw Exception('No se pudo obtener la ubicación');
        }
      }

      // Obtener información del usuario
      final userInfo = _userService.getUserInfoForAlert();
      final userName = _userService.getUserDisplayName(isAnonymous: isAnonymous);

      // Crear modelo de alerta
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
      );

      // Guardar en Firestore
      final alertId = await _alertRepository.saveAlert(alert);

      // Si hay imagen, convertirla a Base64 y actualizar el documento
      if (images != null && images.isNotEmpty) {
        await _imageService.convertImageToBase64AndUpdateAlert(images.first, 
          FirebaseFirestore.instance.collection('alerts').doc(alertId));
      }

      // Las notificaciones se manejan automáticamente por GuardianBackgroundService.kt

      return true;
    } catch (e) {
      print('Error enviando alerta detallada: $e');
      return false;
    }
  }

  /// Envía una alerta rápida a Firebase
  /// Envía a todas las comunidades configuradas en QuickAlertConfigService
  /// Por defecto: todas las entidades
  /// [alertType] - Tipo de alerta
  /// [isAnonymous] - Si la alerta debe ser anónima
  Future<bool> sendQuickAlert({
    required String alertType,
    required bool isAnonymous,
  }) async {
    try {
      // Verificar que el usuario puede enviar alertas
      if (!_userService.canUserSendAlerts()) {
        throw Exception('Usuario no autenticado');
      }

      // Solicitar permisos de ubicación (siempre requerida para alertas rápidas)
      final hasLocationPermission = await PermissionService.requestLocationPermissionForAlerts();
      if (!hasLocationPermission) {
        throw Exception('Permisos de ubicación requeridos para enviar alertas rápidas');
      }

      // Obtener ubicación (siempre requerida para alertas rápidas)
      final locationData = await _locationService.getCurrentLocation();
      if (locationData == null) {
        throw Exception('No se pudo obtener la ubicación');
      }

      // Obtener información del usuario
      final userInfo = _userService.getUserInfoForAlert();
      final userName = _userService.getUserDisplayName(isAnonymous: isAnonymous);

      // Obtener destinos configurados para quick alerts
      final configService = QuickAlertConfigService();
      final destinations = await configService.getQuickAlertDestinations();
      
      if (destinations.isEmpty) {
        throw Exception('No hay destinos configurados para quick alerts');
      }

      // Crear una alerta por cada comunidad configurada
      // Usar batch write para optimizar (plan gratuito)
      final batch = FirebaseFirestore.instance.batch();
      final timestamp = DateTime.now();
      
      for (final communityId in destinations) {
        final alert = AlertModel(
          type: 'quick',
          alertType: alertType,
          timestamp: timestamp,
          isAnonymous: isAnonymous,
          shareLocation: true,
          location: locationData,
          userId: !isAnonymous ? userInfo['userId'] : null,
          userEmail: !isAnonymous ? userInfo['userEmail'] : null,
          userName: userName,
          viewedCount: 0,
          viewedBy: [],
          communityId: communityId, // Enviar a esta comunidad
          forwardsCount: 0,
          reportsCount: 0,
        );

        // Agregar al batch
        final alertRef = FirebaseFirestore.instance.collection('alerts').doc();
        batch.set(alertRef, alert.toFirestore());
      }

      // Ejecutar batch (1 write operation para todas las alertas)
      await batch.commit();

      print('✅ Quick alert enviada a ${destinations.length} comunidades');
      
      // Las notificaciones se manejan automáticamente por GuardianBackgroundService.kt

      return true;
    } catch (e) {
      print('Error enviando alerta rápida: $e');
      return false;
    }
  }

  /// Envía una alerta deslizada a Firebase
  /// [alertType] - Tipo de alerta (ej: "STREET ESCORT", "ROBBERY", etc.)
  /// [isAnonymous] - Si la alerta debe ser anónima
  /// [communityId] - ID de la comunidad a la que se envía la alerta
  Future<bool> sendSwipedAlert({
    required String alertType,
    required bool isAnonymous,
    required String communityId,
  }) async {
    try {
      // Verificar que el usuario puede enviar alertas
      if (!_userService.canUserSendAlerts()) {
        throw Exception('Usuario no autenticado');
      }

      // Solicitar permisos de ubicación (siempre requerida para alertas deslizadas)
      final hasLocationPermission = await PermissionService.requestLocationPermissionForAlerts();
      if (!hasLocationPermission) {
        throw Exception('Permisos de ubicación requeridos para enviar alertas deslizadas');
      }

      // Obtener ubicación (siempre requerida para alertas deslizadas)
      final locationData = await _locationService.getCurrentLocation();
      if (locationData == null) {
        throw Exception('No se pudo obtener la ubicación');
      }

      // Obtener información del usuario
      final userInfo = _userService.getUserInfoForAlert();
      final userName = _userService.getUserDisplayName(isAnonymous: isAnonymous);

      // Crear modelo de alerta
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
        // NUEVO: comunidad seleccionada
        communityId: communityId,
        forwardsCount: 0,
        reportsCount: 0,
      );

      // Guardar en Firestore
      await _alertRepository.saveAlert(alert);

      // Las notificaciones se manejan automáticamente por GuardianBackgroundService.kt

      return true;
    } catch (e) {
      print('Error enviando alerta deslizada: $e');
      return false;
    }
  }

  /// Marca una alerta como vista por el usuario actual
  Future<void> markAlertAsViewed(String alertId) async {
    try {
      await _alertRepository.markAlertAsViewed(alertId);
    } catch (e) {
      print('Error marking alert as viewed: $e');
    }
  }

  /// Verifica si el usuario tiene permisos de ubicación
  Future<bool> hasLocationPermission() async {
    return await _locationService.hasLocationPermission();
  }

  /// Solicita permisos de ubicación
  Future<bool> requestLocationPermission() async {
    return await _locationService.requestLocationPermission();
  }

  /// Reenvía una alerta a múltiples comunidades/entidades
  /// [alertId] - ID de la alerta original
  /// [targetCommunityIds] - Lista de IDs de comunidades destino
  /// Retorna el número de comunidades a las que se reenvió exitosamente
  Future<int> forwardAlert({
    required String alertId,
    required List<String> targetCommunityIds,
  }) async {
    try {
      if (targetCommunityIds.isEmpty) {
        throw Exception('Debe seleccionar al menos una comunidad destino');
      }

      // Verificar que el usuario puede enviar alertas
      if (!_userService.canUserSendAlerts()) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener la alerta original
      final alertDoc = await FirebaseFirestore.instance
          .collection('alerts')
          .doc(alertId)
          .get();

      if (!alertDoc.exists) {
        throw Exception('Alerta no encontrada');
      }

      final originalAlert = AlertModel.fromFirestore(alertDoc);

      // Si la alerta original tiene comunidad, verificar allow_forward_to_entities
      if (originalAlert.communityId != null && originalAlert.communityId!.isNotEmpty) {
        final communityRepo = CommunityRepository();
        final originalCommunity = await communityRepo.getCommunityById(originalAlert.communityId!);
        
        if (originalCommunity != null) {
          // Obtener todas las comunidades destino para verificar si alguna es entidad
          final communityService = CommunityService();
          final allCommunities = await communityService.getMyCommunities();
          
          // Verificar si alguna comunidad destino es entidad
          final targetCommunities = allCommunities.where(
            (c) => targetCommunityIds.contains(c['id'] as String),
          ).toList();
          
          final hasEntityTarget = targetCommunities.any((c) => c['is_entity'] == true);
          
          // Si se intenta reenviar a entidades y no está permitido
          if (hasEntityTarget && !originalCommunity.allowForwardToEntities) {
            throw Exception('Esta comunidad no permite reenviar alertas a entidades');
          }
        }
      }

      // Obtener información del usuario actual (para la nueva alerta)
      final userInfo = _userService.getUserInfoForAlert();
      final userName = _userService.getUserDisplayName(isAnonymous: false);

      // Crear copias de la alerta para cada comunidad destino
      // Usar batch write para optimizar (plan gratuito)
      final batch = FirebaseFirestore.instance.batch();
      final timestamp = DateTime.now();
      int successCount = 0;

      for (final targetCommunityId in targetCommunityIds) {
        // Crear copia de la alerta con nueva comunidad
        final forwardedAlert = AlertModel(
          type: originalAlert.type,
          alertType: originalAlert.alertType,
          description: originalAlert.description,
          timestamp: timestamp,
          isAnonymous: false, // Alertas reenviadas no son anónimas
          shareLocation: originalAlert.shareLocation,
          location: originalAlert.location,
          userId: userInfo['userId'],
          userEmail: userInfo['userEmail'],
          userName: userName,
          viewedCount: 0,
          viewedBy: [],
          communityId: targetCommunityId, // Nueva comunidad destino
          forwardsCount: 0, // Nueva alerta, sin reenvíos
          reportsCount: 0,
          imageBase64: originalAlert.imageBase64, // Copiar imagen si existe
        );

        // Agregar al batch
        final alertRef = FirebaseFirestore.instance.collection('alerts').doc();
        batch.set(alertRef, forwardedAlert.toFirestore());
        successCount++;
      }

      // Incrementar forwards_count en la alerta original
      final currentForwardsCount = originalAlert.forwardsCount;
      batch.update(
        FirebaseFirestore.instance.collection('alerts').doc(alertId),
        {'forwards_count': currentForwardsCount + successCount},
      );

      // Ejecutar batch (1 write operation para todas las alertas + actualización)
      await batch.commit();

      print('✅ Alerta reenviada a $successCount comunidades');
      return successCount;
    } catch (e) {
      print('❌ Error reenviando alerta: $e');
      rethrow;
    }
  }
} 