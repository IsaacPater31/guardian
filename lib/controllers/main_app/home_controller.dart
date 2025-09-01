import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../../models/alert_model.dart';
import '../../services/notification_service.dart';
import '../../services/background_service.dart';
import '../../services/alert_repository.dart';
import '../../services/user_service.dart';

class HomeController {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final NotificationService _notificationService = NotificationService();
  final BackgroundService _backgroundService = BackgroundService();
  final AlertRepository _alertRepository = AlertRepository();
  final UserService _userService = UserService();
  
  StreamSubscription<List<AlertModel>>? _alertsSubscription;
  StreamSubscription<AlertModel>? _notificationSubscription;
  List<AlertModel> _recentAlerts = [];
  bool _isInitialized = false;
  
  // Callbacks para actualizar la UI
  Function(List<AlertModel>)? onAlertsUpdated;
  Function(AlertModel)? onNewAlertReceived;
  
  List<AlertModel> get recentAlerts => _recentAlerts;
  
  /// Inicializa el controlador y configura las notificaciones
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Iniciar escucha de alertas INMEDIATAMENTE (sin esperar permisos)
    await _startListeningToAlerts();
    
    // Configurar notificaciones en paralelo (no bloquear)
    _setupNotificationsInBackground();
    _notificationService.initialize();
    _backgroundService.initialize();
    await _startListeningToNotifications();
    await _backgroundService.startBackgroundMonitoring();
    await _notificationService.saveTokenToFirestore();
    _isInitialized = true;
  }
  
  /// Configura las notificaciones locales en segundo plano (sin bloquear)
  Future<void> _setupNotificationsInBackground() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      // Configurar canal de notificaciones para Android
      const androidChannel = AndroidNotificationChannel(
        'emergency_alerts',
        'Emergency Alerts',
        description: 'Notifications for emergency alerts in your area',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );
      
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    } catch (e) {
      print('⚠️ Error setting up notifications (non-blocking): $e');
    }
  }
  
  /// Inicia la escucha de alertas en tiempo real
  Future<void> _startListeningToAlerts() async {
    _alertsSubscription = _alertRepository.getRecentAlertsStream().listen(_handleAlertsUpdate);
  }

  /// Inicia la escucha de notificaciones push
  Future<void> _startListeningToNotifications() async {
    // En Android, NO usar FCM - solo notificaciones locales desde el servicio
    if (Platform.isAndroid) {
      print('📱 Android detected - Skipping FCM, using local notifications only');
      return;
    }
    
    // Solo en iOS usar FCM
    _notificationSubscription = _notificationService.alertStream.listen((alert) {
      onNewAlertReceived?.call(alert);
    });
  }
  
  /// Maneja las actualizaciones de alertas
  void _handleAlertsUpdate(List<AlertModel> alerts) {
    _recentAlerts = alerts;
    
    // Notificar a la UI
    onAlertsUpdated?.call(_recentAlerts);
    
    // Verificar si hay alertas nuevas
    _checkForNewAlerts(alerts);
  }
  
  /// Verifica si hay alertas nuevas y las notifica
  void _checkForNewAlerts(List<AlertModel> alerts) async {
    // Solo procesar alertas de los últimos 30 segundos como "nuevas"
    final thirtySecondsAgo = DateTime.now().subtract(const Duration(seconds: 30));
    
    // Obtener el usuario actual
    final currentUser = _userService.currentUser;
    if (currentUser == null) return;
    
    for (final alert in alerts) {
      if (alert.timestamp.isAfter(thirtySecondsAgo)) {
        // No mostrar notificación si la alerta fue creada por el usuario actual
        if (alert.userId != currentUser.uid) {
          // En Android, NO mostrar notificación local aquí (ya se maneja en el servicio)
          // En iOS, mostrar notificación local
          if (!Platform.isAndroid) {
            _showAlertNotification(alert);
          }
        }
        // Llamar al callback para actualizar la UI (siempre)
        onNewAlertReceived?.call(alert);
      }
    }
  }
  
  /// Muestra una notificación local para una alerta (solo Android)
  Future<void> _showAlertNotification(AlertModel alert) async {
    // Solo mostrar notificaciones locales en Android
    if (!Platform.isAndroid) return;
    
    const androidDetails = AndroidNotificationDetails(
      'emergency_alerts',
      'Emergency Alerts',
      channelDescription: 'Notifications for emergency alerts in your area',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      color: Color(0xFFD32F2F),
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
    );
    
    const details = NotificationDetails(android: androidDetails);
    
    // Crear título y contenido de la notificación
    final title = _getAlertTitle(alert);
    final body = _getAlertBody(alert);
    
    await _notifications.show(
      alert.hashCode, // ID único basado en el hash de la alerta
      title,
      body,
      details,
      payload: alert.id, // Pasar el ID de la alerta como payload
    );
    
    // Iniciar vibración continua
    _startContinuousVibration();
  }
  
  /// Genera el título de la notificación
  String _getAlertTitle(AlertModel alert) {
    switch (alert.alertType) {
      case 'ROBBERY':
        return '🚨 Robo Reportado';
      case 'FIRE':
        return '🔥 Incendio Reportado';
      case 'ACCIDENT':
        return '🚗 Accidente Reportado';
      case 'STREET ESCORT':
        return '👥 Acompañamiento Solicitado';
      case 'UNSAFETY':
        return '⚠️ Zona Insegura';
      case 'PHYSICAL RISK':
        return '🚨 Riesgo Físico';
      case 'PUBLIC SERVICES EMERGENCY':
        return '🏗️ Emergencia Servicios Públicos';
      case 'VIAL EMERGENCY':
        return '🚦 Emergencia Vial';
      case 'ASSISTANCE':
        return '🆘 Asistencia Necesaria';
      case 'EMERGENCY':
        return '🚨 Emergencia General';
      default:
        return '🚨 Alerta de Emergencia';
    }
  }
  
  /// Genera el contenido de la notificación
  String _getAlertBody(AlertModel alert) {
    String body = '${alert.alertType}';
    
    if (alert.description != null && alert.description!.isNotEmpty) {
      body += '\n${alert.description}';
    }
    
    if (alert.shareLocation && alert.location != null) {
      body += '\n📍 Ubicación incluida';
    }
    
    if (alert.isAnonymous) {
      body += '\n👤 Reporte anónimo';
    }

    // Agregar información sobre el contador de vistas
    if (alert.viewedCount > 0) {
      body += '\n👁️ Visto por ${alert.viewedCount} persona${alert.viewedCount > 1 ? 's' : ''}';
    }
    
    return body;
  }
  
  /// Inicia la vibración continua
  Future<void> _startContinuousVibration() async {
    if (await Vibration.hasVibrator() ?? false) {
      // Patrón de vibración: vibrar por 1 segundo, pausa de 0.5 segundos, repetir
      const pattern = [0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000];
      Vibration.vibrate(pattern: pattern, repeat: 2); // Repetir 2 veces
    }
  }
  
  /// Detiene la vibración
  Future<void> stopVibration() async {
    Vibration.cancel();
  }
  
  /// Maneja cuando se toca una notificación
  void _onNotificationTapped(NotificationResponse response) {
    // Aquí puedes navegar a la vista de detalles de la alerta
    // usando el payload (ID de la alerta)
    final alertId = response.payload;
    if (alertId != null) {
      markAlertAsViewed(alertId);
      // TODO: Navegar a la vista de detalles de la alerta
      print('Alert tapped: $alertId');
    }
  }
  
  /// Marca una alerta como vista (detiene la vibración y actualiza el contador)
  Future<void> markAlertAsViewed(String alertId) async {
    await _notificationService.markAlertAsViewed(alertId);
    stopVibration();
  }
  
  /// Obtiene alertas recientes (últimas 24 horas)
  Future<List<AlertModel>> getRecentAlerts() async {
    return await _alertRepository.getRecentAlerts();
  }
  
  /// Obtiene estadísticas de alertas
  Future<Map<String, int>> getAlertStatistics() async {
    return await _alertRepository.getAlertStatistics();
  }

  /// Obtiene estadísticas de vistas
  Future<Map<String, int>> getViewStatistics() async {
    return await _alertRepository.getViewStatistics();
  }
  
  /// Limpia los recursos del controlador
  void dispose() {
    _alertsSubscription?.cancel();
    _notificationSubscription?.cancel();
    stopVibration();
    _backgroundService.stopBackgroundMonitoring();
    _notificationService.dispose();
  }
} 