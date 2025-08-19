import 'dart:io';
import 'background_service_interface.dart';
import 'android_background_service.dart';
import 'ios_background_service.dart';

/// Factory para crear el servicio de segundo plano apropiado según la plataforma
class BackgroundServiceFactory {
  /// Crea y retorna la implementación correcta del servicio según la plataforma
  static BackgroundServiceInterface createService() {
    if (Platform.isAndroid) {
      return AndroidBackgroundService();
    } else if (Platform.isIOS) {
      return IOSBackgroundService();
    } else {
      throw UnsupportedError('Platform not supported for background services');
    }
  }
  
  /// Verifica si la plataforma actual soporta servicios en segundo plano
  static bool isPlatformSupported() {
    return Platform.isAndroid || Platform.isIOS;
  }
  
  /// Obtiene información sobre las capacidades de la plataforma
  static Map<String, dynamic> getPlatformCapabilities() {
    if (Platform.isAndroid) {
      return {
        'platform': 'Android',
        'backgroundService': true,
        'foregroundService': true,
        'persistentNotifications': true,
        'realTimeListening': true,
      };
    } else if (Platform.isIOS) {
      return {
        'platform': 'iOS',
        'backgroundService': false,
        'foregroundService': false,
        'persistentNotifications': false,
        'realTimeListening': false,
        'pushNotifications': true,
      };
    } else {
      return {
        'platform': 'Unknown',
        'backgroundService': false,
        'foregroundService': false,
        'persistentNotifications': false,
        'realTimeListening': false,
      };
    }
  }
}
