import 'dart:convert';
import 'dart:io';

import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/alerts/data/alert_repository.dart';

/// Image encoding helpers and alert image updates.
///
/// Encoding is pure (no Firestore). Persistence goes through [AlertRepository].
class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal({AlertRepository? alertRepository})
      : _alertRepository = alertRepository ?? AlertRepository();

  final AlertRepository _alertRepository;

  static const int defaultMaxSizeKb = 500;

  /// Converts [image] to Base64 and updates the alert in Firestore by [alertId].
  Future<void> convertImageToBase64AndUpdateAlert(
    File image,
    String alertId,
  ) async {
    try {
      final base64String = await encodeImageToBase64(image);
      await _alertRepository.updateAlertImages(
        alertId: alertId,
        imageBase64: [base64String],
      );
    } catch (e) {
      AppLogger.e('ImageService.convertImageToBase64AndUpdateAlert', e);
      await _alertRepository.updateAlertImages(
        alertId: alertId,
        imageBase64: const [],
      );
      rethrow;
    }
  }

  /// Encodes a single image after size validation.
  Future<String> encodeImageToBase64(
    File image, {
    int maxSizeKB = defaultMaxSizeKb,
  }) async {
    if (!await validateImageSize(image, maxSizeKB: maxSizeKB)) {
      throw Exception(
        'La imagen es demasiado grande. Máximo ${maxSizeKB}KB permitido.',
      );
    }
    final imageBytes = await image.readAsBytes();
    return base64Encode(imageBytes);
  }

  /// Verifica si una imagen cumple con los requisitos de tamaño.
  Future<bool> validateImageSize(File image, {int maxSizeKB = defaultMaxSizeKb}) async {
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
        base64Images.add(await encodeImageToBase64(image));
      } catch (e) {
        AppLogger.e('ImageService.convertImagesToBase64', e);
        rethrow;
      }
    }

    return base64Images;
  }

  /// Actualiza una alerta con múltiples imágenes (vía [AlertRepository]).
  Future<void> updateAlertWithImages(
    List<String> base64Images,
    String alertId,
  ) async {
    try {
      await _alertRepository.updateAlertImages(
        alertId: alertId,
        imageBase64: base64Images,
      );
    } catch (e) {
      AppLogger.e('ImageService.updateAlertWithImages', e);
      rethrow;
    }
  }
}
