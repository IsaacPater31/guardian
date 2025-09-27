import 'dart:async';
import 'dart:io';
import '../../models/alert_model.dart';
import '../../services/alert_repository.dart';
import '../../services/user_service.dart';
import '../../services/native_background_service.dart';

class HomeController {
  final AlertRepository _alertRepository = AlertRepository();
  final UserService _userService = UserService();
  
  StreamSubscription<List<AlertModel>>? _alertsSubscription;
  
  // Callbacks para la UI
  Function(List<AlertModel>)? onAlertsUpdated;
  Function(AlertModel)? onNewAlertReceived;
  Function(bool)? onServiceStatusChanged;
  
  /// Inicializa el controlador
  Future<void> initialize() async {
    print('🏠 Initializing HomeController...');
    
    // Iniciar servicio nativo de Android
    if (Platform.isAndroid) {
      try {
        await NativeBackgroundService.startService();
        print('✅ Native background service started');
      } catch (e) {
        print('❌ Error starting native background service: $e');
      }
    }
    
    // Iniciar escucha de alertas
    _startAlertsListener();
  }
  
  /// Inicia el listener de alertas desde Firestore
  void _startAlertsListener() {
    print('👂 Starting alerts listener...');
    
    _alertsSubscription = _alertRepository.getRecentAlertsStream().listen((alerts) {
      print('📊 Received ${alerts.length} alerts');
      
      // Filtrar alertas del usuario actual
      final currentUser = _userService.currentUser;
      if (currentUser != null) {
        final otherUserAlerts = alerts.where((alert) => alert.userId != currentUser.uid).toList();
        
        // Notificar a la UI
        onAlertsUpdated?.call(otherUserAlerts);
        
        // Detectar nuevas alertas
        if (otherUserAlerts.isNotEmpty) {
          final latestAlert = otherUserAlerts.first;
          onNewAlertReceived?.call(latestAlert);
          print('🚨 New alert received: ${latestAlert.alertType}');
        }
      }
    }, onError: (error) {
      print('❌ Error in alerts listener: $error');
    });
  }
  
  /// Obtiene las alertas recientes
  Future<List<AlertModel>> getRecentAlerts() async {
    try {
      final alerts = await _alertRepository.getRecentAlerts();
      final currentUser = _userService.currentUser;
      
      if (currentUser != null) {
        // Filtrar alertas del usuario actual
        return alerts.where((alert) => alert.userId != currentUser.uid).toList();
      }
      
      return alerts;
    } catch (e) {
      print('❌ Error getting recent alerts: $e');
      return [];
    }
  }
  
  /// Verifica si el servicio está ejecutándose
  Future<bool> isServiceRunning() async {
    if (Platform.isAndroid) {
      return await NativeBackgroundService.isServiceRunning();
    }
    return false;
  }
  
  /// Inicia el servicio de fondo
  Future<void> startBackgroundService() async {
    if (Platform.isAndroid) {
      try {
        await NativeBackgroundService.startService();
        onServiceStatusChanged?.call(true);
        print('✅ Background service started');
      } catch (e) {
        print('❌ Error starting background service: $e');
      }
    }
  }
  
  /// Detiene el servicio de fondo
  Future<void> stopBackgroundService() async {
    if (Platform.isAndroid) {
      try {
        await NativeBackgroundService.stopService();
        onServiceStatusChanged?.call(false);
        print('✅ Background service stopped');
      } catch (e) {
        print('❌ Error stopping background service: $e');
      }
    }
  }
  
  /// Marca una alerta como vista
  Future<void> markAlertAsViewed(String alertId) async {
    try {
      await _alertRepository.markAlertAsViewed(alertId);
      print('✅ Alert marked as viewed: $alertId');
    } catch (e) {
      print('❌ Error marking alert as viewed: $e');
    }
  }
  
  /// Limpia recursos del controlador
  Future<void> dispose() async {
    print('🔄 Disposing HomeController...');
    
    // Detener listener de alertas
    await _alertsSubscription?.cancel();
    _alertsSubscription = null;
    
    // Detener servicio de fondo
    if (Platform.isAndroid) {
      try {
        await NativeBackgroundService.stopService();
        print('✅ Background service stopped on dispose');
      } catch (e) {
        print('❌ Error stopping background service on dispose: $e');
      }
    }
    
    print('✅ HomeController disposed');
  }
}