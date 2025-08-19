import '../../models/alert_model.dart';

/// Interfaz base para servicios en segundo plano
/// Define los métodos que deben implementar todas las plataformas
abstract class BackgroundServiceInterface {
  /// Inicia el servicio en segundo plano
  Future<void> startBackgroundService();
  
  /// Detiene el servicio en segundo plano
  Future<void> stopBackgroundService();
  
  /// Verifica si el servicio está ejecutándose
  Future<bool> isServiceRunning();
  
  /// Callback cuando se recibe una alerta
  void onAlertReceived(AlertModel alert);
  
  /// Callback cuando cambia el estado del servicio
  void onServiceStatusChanged(bool isRunning);
  
  /// Inicializa el servicio (configuración inicial)
  Future<void> initialize();
  
  /// Limpia recursos del servicio
  Future<void> dispose();
}
