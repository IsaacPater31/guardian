import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/alert_model.dart';

class AlertController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      // Obtener ubicación si es requerida
      LocationData? locationData;
      if (shareLocation) {
        final locationMap = await _getCurrentLocation();
        if (locationMap == null) {
          throw Exception('No se pudo obtener la ubicación');
        }
        locationData = locationMap;
      }

      // Obtener nombre del usuario
      String? userName;
      if (!isAnonymous && _auth.currentUser != null) {
        userName = _auth.currentUser!.displayName ?? _auth.currentUser!.email?.split('@')[0];
      }

      // Crear modelo de alerta
      final alert = AlertModel(
        type: 'detailed',
        alertType: alertType,
        description: description,
        timestamp: DateTime.now(),
        isAnonymous: isAnonymous,
        shareLocation: shareLocation,
        location: locationData,
        userId: !isAnonymous && _auth.currentUser != null ? _auth.currentUser!.uid : null,
        userEmail: !isAnonymous && _auth.currentUser != null ? _auth.currentUser!.email : null,
        userName: userName,
      );

      // Guardar en Firestore
      final docRef = await _firestore.collection('alerts').add(alert.toFirestore());

      // Si hay imagen, convertirla a Base64 y actualizar el documento
      if (images != null && images.isNotEmpty) {
        await _convertImageToBase64AndUpdateAlert(images.first, docRef);
      }

      return true;
    } catch (e) {
      // Error enviando alerta detallada: $e
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
      // Obtener ubicación (siempre requerida para alertas rápidas)
      final locationMap = await _getCurrentLocation();
      if (locationMap == null) {
        throw Exception('No se pudo obtener la ubicación');
      }
      final locationData = locationMap;

      // Obtener nombre del usuario
      String? userName;
      if (!isAnonymous && _auth.currentUser != null) {
        userName = _auth.currentUser!.displayName ?? _auth.currentUser!.email?.split('@')[0];
      }

      // Crear modelo de alerta
      final alert = AlertModel(
        type: 'quick',
        alertType: alertType,
        timestamp: DateTime.now(),
        isAnonymous: isAnonymous,
        shareLocation: true,
        location: locationData,
        userId: !isAnonymous && _auth.currentUser != null ? _auth.currentUser!.uid : null,
        userEmail: !isAnonymous && _auth.currentUser != null ? _auth.currentUser!.email : null,
        userName: userName,
      );

      // Guardar en Firestore
      await _firestore.collection('alerts').add(alert.toFirestore());

      return true;
    } catch (e) {
      // Error enviando alerta rápida: $e
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
      // Obtener ubicación (siempre requerida para alertas deslizadas)
      final locationMap = await _getCurrentLocation();
      if (locationMap == null) {
        throw Exception('No se pudo obtener la ubicación');
      }
      final locationData = locationMap;

      // Obtener nombre del usuario
      String? userName;
      if (!isAnonymous && _auth.currentUser != null) {
        userName = _auth.currentUser!.displayName ?? _auth.currentUser!.email?.split('@')[0];
      }

      // Crear modelo de alerta
      final alert = AlertModel(
        type: 'swiped',
        alertType: alertType, // Usar el tipo de alerta correcto
        timestamp: DateTime.now(),
        isAnonymous: isAnonymous,
        shareLocation: true,
        location: locationData,
        userId: !isAnonymous && _auth.currentUser != null ? _auth.currentUser!.uid : null,
        userEmail: !isAnonymous && _auth.currentUser != null ? _auth.currentUser!.email : null,
        userName: userName,
      );

      // Guardar en Firestore
      await _firestore.collection('alerts').add(alert.toFirestore());

      return true;
    } catch (e) {
      // Error enviando alerta deslizada: $e
      return false;
    }
  }

  /// Obtiene la ubicación actual del dispositivo
  Future<LocationData?> _getCurrentLocation() async {
    try {
      // Verificar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Obtener ubicación actual
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      // Error getting location: $e
      return null;
    }
  }

  /// Convierte imagen a Base64 y actualiza la alerta
  Future<void> _convertImageToBase64AndUpdateAlert(File image, DocumentReference docRef) async {
    try {
      // Verificar tamaño de la imagen antes de convertir
      final bytes = await image.length();
      final sizeInKB = bytes / 1024;
      
      if (sizeInKB > 500) {
        throw Exception('La imagen es demasiado grande. Máximo 500KB permitido.');
      }
      
      // Leer el archivo como bytes
      final imageBytes = await image.readAsBytes();
      
      // Convertir a Base64
      final base64String = base64Encode(imageBytes);
      
      // Actualizar el documento con la imagen en Base64
      await docRef.update({
        'hasImages': true,
        'imageCount': 1,
        'imageBase64': [base64String],
      });
    } catch (e) {
      // Error converting image to Base64: $e
      // Si falla la conversión, al menos actualizar que hay imagen
      await docRef.update({
        'hasImages': true,
        'imageCount': 1,
        'imageBase64': [],
      });
      rethrow; // Re-lanzar el error para que se maneje en la UI
    }
  }

  /// Verifica si el usuario tiene permisos de ubicación
  Future<bool> hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  /// Solicita permisos de ubicación
  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }
} 