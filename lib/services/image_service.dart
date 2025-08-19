import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  /// Convierte una imagen a Base64 y actualiza la alerta en Firestore
  Future<void> convertImageToBase64AndUpdateAlert(File image, DocumentReference docRef) async {
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
      print('Error converting image to Base64: $e');
      // Si falla la conversión, al menos actualizar que hay imagen
      await docRef.update({
        'hasImages': true,
        'imageCount': 1,
        'imageBase64': [],
      });
      rethrow; // Re-lanzar el error para que se maneje en la UI
    }
  }

  /// Verifica si una imagen cumple con los requisitos de tamaño
  Future<bool> validateImageSize(File image, {int maxSizeKB = 500}) async {
    try {
      final bytes = await image.length();
      final sizeInKB = bytes / 1024;
      return sizeInKB <= maxSizeKB;
    } catch (e) {
      print('Error validating image size: $e');
      return false;
    }
  }

  /// Obtiene el tamaño de una imagen en KB
  Future<double> getImageSizeInKB(File image) async {
    try {
      final bytes = await image.length();
      return bytes / 1024;
    } catch (e) {
      print('Error getting image size: $e');
      return 0.0;
    }
  }

  /// Convierte múltiples imágenes a Base64
  Future<List<String>> convertImagesToBase64(List<File> images) async {
    final List<String> base64Images = [];
    
    for (final image in images) {
      try {
        // Verificar tamaño
        if (!await validateImageSize(image)) {
          throw Exception('La imagen ${image.path} es demasiado grande.');
        }
        
        // Leer y convertir
        final imageBytes = await image.readAsBytes();
        final base64String = base64Encode(imageBytes);
        base64Images.add(base64String);
      } catch (e) {
        print('Error converting image ${image.path}: $e');
        rethrow;
      }
    }
    
    return base64Images;
  }

  /// Actualiza una alerta con múltiples imágenes
  Future<void> updateAlertWithImages(List<String> base64Images, DocumentReference docRef) async {
    try {
      await docRef.update({
        'hasImages': true,
        'imageCount': base64Images.length,
        'imageBase64': base64Images,
      });
    } catch (e) {
      print('Error updating alert with images: $e');
      rethrow;
    }
  }
}
