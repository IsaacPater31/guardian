import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vibration/vibration.dart';
import '../../models/alert_model.dart';
import 'background_service_interface.dart';

/// Implementación de servicio en segundo plano para iOS
/// iOS NO permite servicios en segundo plano persistentes
/// Solo usa push notifications para recibir alertas
class IOSBackgroundService implements BackgroundServiceInterface {
  static const String ALERTS_CHANNEL_ID = 'emergency_alerts';
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  bool _isInitialized = false;
  bool _isServiceRunning = false;
  
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _setupNotificationChannels();
    await _setupFirebaseMessaging();
    _isInitialized = true;
  }
  
  Future<void> _setupNotificationChannels() async {
    // En iOS no necesitamos crear canales como en Android
    // Solo solicitamos permisos
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }
  
  Future<void> _setupFirebaseMessaging() async {
    // Solicitar permisos de notificación
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );
    
    print('iOS notification permission status: ${settings.authorizationStatus}');
    
    // Suscribirse al topic de alertas
    await _firebaseMessaging.subscribeToTopic('emergency_alerts');
    
    // Configurar handlers para diferentes estados de la app
    _setupMessageHandlers();
  }
  
  void _setupMessageHandlers() {
    // Mensajes cuando la app está en primer plano
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Mensajes cuando se toca la notificación y la app está en segundo plano
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
    
    // Mensajes cuando se toca la notificación y la app está cerrada
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleBackgroundMessage(message);
      }
    });
  }
  
  void _handleForegroundMessage(RemoteMessage message) {
    print('📱 iOS foreground message received: ${message.data}');
    
    if (message.data.containsKey('alertId')) {
      _fetchAndDisplayAlert(message.data['alertId']);
    }
  }
  
  void _handleBackgroundMessage(RemoteMessage message) {
    print('📱 iOS background message received: ${message.data}');
    
    if (message.data.containsKey('alertId')) {
      _fetchAndDisplayAlert(message.data['alertId']);
    }
  }
  
  Future<void> _fetchAndDisplayAlert(String alertId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('alerts')
          .doc(alertId)
          .get();
      
      if (doc.exists) {
        final alert = AlertModel.fromFirestore(doc);
        onAlertReceived(alert);
      }
    } catch (e) {
      print('❌ Error fetching alert in iOS: $e');
    }
  }
  
  @override
  Future<void> startBackgroundService() async {
    if (!_isInitialized) await initialize();
    
    try {
      // En iOS, el "servicio" es solo configurar push notifications
      // No hay servicio real en segundo plano
      _isServiceRunning = true;
      onServiceStatusChanged(true);
      
      print('✅ iOS background service (push notifications) configured successfully');
    } catch (e) {
      print('❌ Error configuring iOS background service: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> stopBackgroundService() async {
    try {
      // Cancelar suscripción al topic
      await _firebaseMessaging.unsubscribeFromTopic('emergency_alerts');
      
      // Cancelar suscripción de mensajes en primer plano
      await _foregroundMessageSubscription?.cancel();
      _foregroundMessageSubscription = null;
      
      _isServiceRunning = false;
      onServiceStatusChanged(false);
      
      print('✅ iOS background service stopped successfully');
    } catch (e) {
      print('❌ Error stopping iOS background service: $e');
      rethrow;
    }
  }
  
  @override
  Future<bool> isServiceRunning() async {
    // En iOS, siempre retorna false porque no hay servicio real en segundo plano
    // Las notificaciones vienen por FCM independientemente del estado
    return false;
  }
  
  @override
  void onAlertReceived(AlertModel alert) {
    // Solo mostrar notificación local si la app está en primer plano
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _showLocalNotification(alert);
      _vibrate();
    }
    
    print('🚨 Alert received in iOS: ${alert.alertType}');
  }
  
  Future<void> _showLocalNotification(AlertModel alert) async {
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
    );
    
    const details = NotificationDetails(iOS: iosDetails);
    
    final title = _getAlertTitle(alert);
    final body = _getAlertBody(alert);
    
    await _notifications.show(
      alert.hashCode,
      title,
      body,
      details,
      payload: alert.id,
    );
  }
  
  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      // Patrón de vibración más sutil para iOS
      const pattern = [0, 500, 200, 500];
      Vibration.vibrate(pattern: pattern, repeat: 1);
    }
  }
  
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
    
    return body;
  }
  
  @override
  void onServiceStatusChanged(bool isRunning) {
    print('🔄 iOS background service status changed: $isRunning');
    // En iOS, esto siempre será false porque no hay servicio real
  }
  
  @override
  Future<void> dispose() async {
    await stopBackgroundService();
    _isInitialized = false;
  }
  
  /// Método específico para iOS: obtener token FCM
  Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }
  
  /// Método específico para iOS: guardar token en Firestore
  Future<void> saveTokenToFirestore(String userId) async {
    final token = await getFCMToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'fcmToken': token,
        'platform': 'iOS',
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
