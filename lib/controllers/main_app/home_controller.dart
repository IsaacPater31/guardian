import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../../models/alert_model.dart';
import '../../services/notification_service.dart';
import '../../services/background_service.dart';

class HomeController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final NotificationService _notificationService = NotificationService();
  final BackgroundService _backgroundService = BackgroundService();
  
  StreamSubscription<QuerySnapshot>? _alertsSubscription;
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
    
    await _setupNotifications();
    await _notificationService.initialize();
    await _backgroundService.initialize();
    await _startListeningToAlerts();
    await _startListeningToNotifications();
    await _backgroundService.startBackgroundMonitoring();
    await _notificationService.saveTokenToFirestore();
    _isInitialized = true;
  }
  
  /// Configura las notificaciones locales
  Future<void> _setupNotifications() async {
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
  }
  
  /// Inicia la escucha de alertas en tiempo real
  Future<void> _startListeningToAlerts() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    // Escuchar alertas de los últimos 24 horas
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    
    _alertsSubscription = _firestore
        .collection('alerts')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(_handleAlertsUpdate);
  }

  /// Inicia la escucha de notificaciones push
  Future<void> _startListeningToNotifications() async {
    _notificationSubscription = _notificationService.alertStream.listen((alert) {
      onNewAlertReceived?.call(alert);
    });
  }
  
  /// Maneja las actualizaciones de alertas
  void _handleAlertsUpdate(QuerySnapshot snapshot) {
    final newAlerts = snapshot.docs
        .map((doc) => AlertModel.fromFirestore(doc))
        .where((alert) => _shouldShowAlert(alert)) // Filtrar alertas propias
        .toList();
    
    _recentAlerts = newAlerts;
    
    // Notificar a la UI
    onAlertsUpdated?.call(_recentAlerts);
    
    // Verificar si hay alertas nuevas
    _checkForNewAlerts(newAlerts);
  }
  
  /// Determina si se debe mostrar una alerta (evita mostrar alertas propias)
  bool _shouldShowAlert(AlertModel alert) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return true;
    
    // Si la alerta es anónima, siempre mostrarla
    if (alert.isAnonymous) return true;
    
    // Si la alerta tiene userId y coincide con el usuario actual, no mostrarla
    if (alert.userId != null && alert.userId == currentUser.uid) {
      return false;
    }
    
    // Si la alerta tiene userEmail y coincide con el usuario actual, no mostrarla
    if (alert.userEmail != null && alert.userEmail == currentUser.email) {
      return false;
    }
    
    return true;
  }
  
  /// Verifica si hay alertas nuevas y las notifica
  void _checkForNewAlerts(List<AlertModel> alerts) {
    // Solo procesar alertas de los últimos 30 segundos como "nuevas"
    final thirtySecondsAgo = DateTime.now().subtract(const Duration(seconds: 30));
    
    for (final alert in alerts) {
      if (alert.timestamp.isAfter(thirtySecondsAgo)) {
        _showAlertNotification(alert);
        onNewAlertReceived?.call(alert);
      }
    }
  }
  
  /// Muestra una notificación para una alerta
  Future<void> _showAlertNotification(AlertModel alert) async {
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
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
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
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    
    final snapshot = await _firestore
        .collection('alerts')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
        .orderBy('timestamp', descending: true)
        .get();
    
    return snapshot.docs
        .map((doc) => AlertModel.fromFirestore(doc))
        .where((alert) => _shouldShowAlert(alert))
        .toList();
  }
  
  /// Obtiene estadísticas de alertas
  Map<String, int> getAlertStatistics() {
    final stats = <String, int>{};
    
    for (final alert in _recentAlerts) {
      stats[alert.alertType] = (stats[alert.alertType] ?? 0) + 1;
    }
    
    return stats;
  }

  /// Obtiene estadísticas de vistas
  Map<String, int> getViewStatistics() {
    final stats = <String, int>{};
    
    for (final alert in _recentAlerts) {
      stats[alert.alertType] = (stats[alert.alertType] ?? 0) + alert.viewedCount;
    }
    
    return stats;
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