import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';
import '../services/alert_repository.dart';
import '../services/location_service.dart';
import '../services/image_service.dart';
import '../services/user_service.dart';
import '../services/permission_service.dart';

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

      // Enviar notificación push a otros usuarios
      final alertWithId = alert.copyWith(id: alertId);
      // Las notificaciones se manejan automáticamente por GuardianBackgroundService.kt

      return true;
    } catch (e) {
      print('Error enviando alerta detallada: $e');
      return false;
    }
  }

  /// Envía una alerta rápida a Firebase
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

      // Crear modelo de alerta
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
      );

      // Guardar en Firestore
      final alertId = await _alertRepository.saveAlert(alert);

      // Enviar notificación push a otros usuarios
      final alertWithId = alert.copyWith(id: alertId);
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
  Future<bool> sendSwipedAlert({
    required String alertType,
    required bool isAnonymous,
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
      );

      // Guardar en Firestore
      final alertId = await _alertRepository.saveAlert(alert);

      // Enviar notificación push a otros usuarios
      final alertWithId = alert.copyWith(id: alertId);
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
} 