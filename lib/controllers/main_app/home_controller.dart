import 'dart:async';
import 'dart:io';
import '../../models/alert_model.dart';
import '../../services/alert_repository.dart';
import '../../services/user_service.dart';
import '../../services/native_background_service.dart';

class HomeController {
  // Singleton pattern para evitar múltiples instancias
  static final HomeController _instance = HomeController._internal();
  factory HomeController() => _instance;
  HomeController._internal();
  
  final AlertRepository _alertRepository = AlertRepository();
  final UserService _userService = UserService();
  
  StreamSubscription<List<AlertModel>>? _alertsSubscription;
  bool _isInitialized = false;
  List<AlertModel> _lastKnownAlerts = [];
  Set<String> _processedAlertIds = <String>{};
  
  // Callbacks para la UI
  Function(List<AlertModel>)? onAlertsUpdated;
  Function(AlertModel)? onNewAlertReceived;
  Function(bool)? onServiceStatusChanged;
  
  /// Inicializa el controlador
  Future<void> initialize() async {
    if (_isInitialized) {
      print('🏠 HomeController already initialized, loading recent alerts...');
      // Cargar alertas recientes aunque ya esté inicializado
      await _loadRecentAlerts();
      return;
    }
    
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
    
    // Cargar alertas recientes iniciales
    await _loadRecentAlerts();
    
    _isInitialized = true;
    print('✅ HomeController initialized successfully');
  }
  
  /// Carga las alertas recientes sin generar notificaciones
  Future<void> _loadRecentAlerts() async {
    try {
      final alerts = await getRecentAlerts();
      print('📊 Loaded ${alerts.length} recent alerts');
      
      // Notificar a la UI con las alertas cargadas
      onAlertsUpdated?.call(alerts);
      
      // Actualizar la lista de alertas conocidas
      _lastKnownAlerts = alerts;
      
      // Marcar todas las alertas existentes como procesadas para evitar notificaciones
      for (final alert in alerts) {
        if (alert.id != null) {
          _processedAlertIds.add(alert.id!);
        }
      }
      
      print('✅ Recent alerts loaded and marked as processed');
    } catch (e) {
      print('❌ Error loading recent alerts: $e');
    }
  }

  /// Inicia el listener de alertas desde Firestore
  void _startAlertsListener() {
    print('👂 Starting alerts listener...');
    
    _alertsSubscription = _alertRepository.getRecentAlertsStream().listen((alerts) {
      print('📊 Received ${alerts.length} alerts from stream');
      
      // Filtrar alertas del usuario actual
      final currentUser = _userService.currentUser;
      if (currentUser != null) {
        final otherUserAlerts = alerts.where((alert) => alert.userId != currentUser.uid).toList();
        
        // Notificar a la UI
        onAlertsUpdated?.call(otherUserAlerts);
        
        // Detectar nuevas alertas - solo notificar si es realmente nueva
        if (otherUserAlerts.isNotEmpty) {
          final latestAlert = otherUserAlerts.first;
          
          // Verificar si esta alerta ya fue procesada
          if (latestAlert.id != null && !_processedAlertIds.contains(latestAlert.id)) {
            _processedAlertIds.add(latestAlert.id!);
            onNewAlertReceived?.call(latestAlert);
            print('🚨 New alert received: ${latestAlert.alertType}');
          } else {
            print('🔄 Alert already processed, skipping notification: ${latestAlert.alertType}');
          }
        }
        
        // Actualizar la lista de alertas conocidas
        _lastKnownAlerts = otherUserAlerts;
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
  
  /// Refresca las alertas recientes (para uso desde la UI)
  Future<void> refreshRecentAlerts() async {
    print('🔄 Refreshing recent alerts...');
    await _loadRecentAlerts();
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
    
    // NO detener el servicio de fondo aquí - debe permanecer activo
    // El servicio solo se detiene cuando la app se cierra completamente
    
    _isInitialized = false;
    _lastKnownAlerts.clear();
    _processedAlertIds.clear();
    
    print('✅ HomeController disposed (service remains active)');
  }
  
  /// Método para limpiar completamente el controlador (solo cuando la app se cierra)
  Future<void> disposeCompletely() async {
    print('🔄 Completely disposing HomeController...');
    
    // Detener listener de alertas
    await _alertsSubscription?.cancel();
    _alertsSubscription = null;
    
    // Detener servicio de fondo solo cuando la app se cierra completamente
    if (Platform.isAndroid) {
      try {
        await NativeBackgroundService.stopService();
        print('✅ Background service stopped on complete dispose');
      } catch (e) {
        print('❌ Error stopping background service on complete dispose: $e');
      }
    }
    
    _isInitialized = false;
    _lastKnownAlerts.clear();
    _processedAlertIds.clear();
    
    print('✅ HomeController completely disposed');
  }
}