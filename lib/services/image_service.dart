import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_logger.dart';

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  /// Convierte una imagen a Base64 y actualiza la alerta en Firestore.
  Future<void> convertImageToBase64AndUpdateAlert(File image, DocumentReference docRef) async {
    try {
      final bytes = await image.length();
      final sizeInKB = bytes / 1024;

      if (sizeInKB > 500) {
        throw Exception('La imagen es demasiado grande. Máximo 500KB permitido.');
      }

      final imageBytes = await image.readAsBytes();
      final base64String = base64Encode(imageBytes);

      await docRef.update({
        'hasImages': true,
        'imageCount': 1,
        'imageBase64': [base64String],
      });
    } catch (e) {
      AppLogger.e('ImageService.convertImageToBase64AndUpdateAlert', e);
      await docRef.update({
        'hasImages': true,
        'imageCount': 1,
        'imageBase64': [],
      });
      rethrow;
    }
  }

  /// Verifica si una imagen cumple con los requisitos de tamaño.
  Future<bool> validateImageSize(File image, {int maxSizeKB = 500}) async {
    try {
      final bytes = await image.length();
      final sizeInKB = bytes / 1024;
      return sizeInKB <= maxSizeKB;
    } catch (e) {
      AppLogger.e('ImageService.validateImageSize', e);
      return false;
    }
  }

  /// Obtiene el tamaño de una imagen en KB.
  Future<double> getImageSizeInKB(File image) async {
    try {
      final bytes = await image.length();
      return bytes / 1024;
    } catch (e) {
      AppLogger.e('ImageService.getImageSizeInKB', e);
      return 0.0;
    }
  }

  /// Convierte múltiples imágenes a Base64.
  Future<List<String>> convertImagesToBase64(List<File> images) async {
    final List<String> base64Images = [];

    for (final image in images) {
      try {
        if (!await validateImageSize(image)) {
          throw Exception('La imagen ${image.path} es demasiado grande.');
        }

        final imageBytes = await image.readAsBytes();
        final base64String = base64Encode(imageBytes);
        base64Images.add(base64String);
      } catch (e) {
        AppLogger.e('ImageService.convertImagesToBase64', e);
        rethrow;
      }
    }

    return base64Images;
  }

  /// Actualiza una alerta con múltiples imágenes.
  Future<void> updateAlertWithImages(List<String> base64Images, DocumentReference docRef) async {
    try {
      await docRef.update({
        'hasImages': true,
        'imageCount': base64Images.length,
        'imageBase64': base64Images,
      });
    } catch (e) {
      AppLogger.e('ImageService.updateAlertWithImages', e);
      rethrow;
    }
  }
}
