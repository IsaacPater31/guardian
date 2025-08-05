import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/alert_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream para notificar cuando se recibe una nueva alerta
  final StreamController<AlertModel> _alertController = StreamController<AlertModel>.broadcast();
  Stream<AlertModel> get alertStream => _alertController.stream;

  // Variables para controlar la vibración
  Timer? _vibrationTimer;
  bool _isVibrating = false;

  /// Inicializa el servicio de notificaciones
  Future<void> initialize() async {
    await _setupFirebaseMessaging();
    await _setupLocalNotifications();
    await _requestPermissions();
    await _subscribeToTopic();
  }

  /// Configura Firebase Cloud Messaging
  Future<void> _setupFirebaseMessaging() async {
    // Manejar mensajes cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Manejar cuando se toca una notificación y la app está en segundo plano
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
    
    // Manejar cuando se toca una notificación y la app está cerrada
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessageTap(initialMessage);
    }
  }

  /// Configura las notificaciones locales
  Future<void> _setupLocalNotifications() async {
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

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
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

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Solicita permisos de notificación
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');
  }

  /// Se suscribe al topic de alertas
  Future<void> _subscribeToTopic() async {
    await _firebaseMessaging.subscribeToTopic('emergency_alerts');
  }

  /// Maneja mensajes cuando la app está en primer plano
  void _handleForegroundMessage(RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.data.containsKey('alertId')) {
      // Obtener la alerta desde Firestore
      final alertDoc = await _firestore.collection('alerts').doc(message.data['alertId']).get();
      if (alertDoc.exists) {
        final alert = AlertModel.fromFirestore(alertDoc);
        _showLocalNotification(alert);
        _startContinuousVibration();
        _alertController.add(alert);
      }
    }
  }

  /// Maneja cuando se toca una notificación en segundo plano
  void _handleBackgroundMessageTap(RemoteMessage message) async {
    print('Message opened from background: ${message.data}');
    
    if (message.data.containsKey('alertId')) {
      final alertId = message.data['alertId'];
      await _markAlertAsViewed(alertId);
      // Aquí puedes navegar a la vista de detalles de la alerta
    }
  }

  /// Maneja cuando se toca una notificación local
  void _onLocalNotificationTapped(NotificationResponse response) async {
    if (response.payload != null) {
      await _markAlertAsViewed(response.payload!);
      // Aquí puedes navegar a la vista de detalles de la alerta
    }
  }

  /// Muestra una notificación local
  Future<void> _showLocalNotification(AlertModel alert) async {
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

    final title = _getAlertTitle(alert);
    final body = _getAlertBody(alert);

    await _localNotifications.show(
      alert.hashCode,
      title,
      body,
      details,
      payload: alert.id,
    );
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

    return body;
  }

  /// Inicia la vibración continua
  Future<void> _startContinuousVibration() async {
    if (_isVibrating) return; // Evitar múltiples vibraciones simultáneas
    
    if (await Vibration.hasVibrator() ?? false) {
      _isVibrating = true;
      
      // Patrón de vibración: vibrar por 1 segundo, pausa de 0.5 segundos, repetir
      const pattern = [0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000];
      Vibration.vibrate(pattern: pattern, repeat: 2); // Repetir 2 veces
      
      // Detener la vibración después de 10 segundos
      _vibrationTimer = Timer(const Duration(seconds: 10), () {
        stopVibration();
      });
    }
  }

  /// Detiene la vibración
  Future<void> stopVibration() async {
    _isVibrating = false;
    _vibrationTimer?.cancel();
    Vibration.cancel();
  }

  /// Marca una alerta como vista
  Future<void> _markAlertAsViewed(String alertId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final alertRef = _firestore.collection('alerts').doc(alertId);
      
      await _firestore.runTransaction((transaction) async {
        final alertDoc = await transaction.get(alertRef);
        if (alertDoc.exists) {
          final currentViewedBy = List<String>.from(alertDoc.data()?['viewedBy'] ?? []);
          final currentViewedCount = alertDoc.data()?['viewedCount'] ?? 0;
          
          // Solo incrementar si el usuario no ha visto la alerta antes
          if (!currentViewedBy.contains(currentUser.uid)) {
            currentViewedBy.add(currentUser.uid);
            transaction.update(alertRef, {
              'viewedBy': currentViewedBy,
              'viewedCount': currentViewedCount + 1,
            });
          }
        }
      });
      
      // Detener la vibración cuando se marca como vista
      stopVibration();
      
    } catch (e) {
      print('Error marking alert as viewed: $e');
    }
  }

  /// Marca una alerta como vista manualmente
  Future<void> markAlertAsViewed(String alertId) async {
    await _markAlertAsViewed(alertId);
  }

  /// Obtiene el token FCM del dispositivo
  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Guarda el token FCM en Firestore para el usuario actual
  Future<void> saveTokenToFirestore() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final token = await getToken();
    if (token != null) {
      await _firestore.collection('users').doc(currentUser.uid).set({
        'fcmToken': token,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Limpia los recursos
  void dispose() {
    stopVibration();
    _alertController.close();
  }
} 