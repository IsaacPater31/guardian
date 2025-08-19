import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vibration/vibration.dart';
import '../../models/alert_model.dart';
import '../../services/user_service.dart';
import '../../services/native_background_service.dart';
import 'background_service_interface.dart';

/// Implementación de servicio en segundo plano para Android
/// Usa Foreground Service para mantener la app escuchando alertas
class AndroidBackgroundService implements BackgroundServiceInterface {
  static const int NOTIFICATION_ID = 1001;
  static const String CHANNEL_ID = 'guardian_background_service';
  static const String ALERTS_CHANNEL_ID = 'emergency_alerts';
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final UserService _userService = UserService();
  StreamSubscription<QuerySnapshot>? _alertsSubscription;
  bool _isInitialized = false;
  bool _isServiceRunning = false;
  
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _setupNotificationChannels();
    await _setupNotificationHandlers();
    _isInitialized = true;
  }
  
  Future<void> _setupNotificationChannels() async {
    // Canal para el servicio en segundo plano
    const backgroundChannel = AndroidNotificationChannel(
      CHANNEL_ID,
      'Guardian Background Service',
      description: 'Mantiene Guardian escuchando alertas en segundo plano',
      importance: Importance.low,
    );
    
    // Canal para alertas de emergencia
    const alertsChannel = AndroidNotificationChannel(
      ALERTS_CHANNEL_ID,
      'Emergency Alerts',
      description: 'Alertas de emergencia en tu área',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(backgroundChannel);
        
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alertsChannel);
  }
  
  Future<void> _setupNotificationHandlers() async {
    // Configurar el handler para cuando se toca una notificación
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }
  
  void _onNotificationTapped(NotificationResponse response) async {
    print('📱 Notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      // Detener la vibración cuando se toca la notificación
      _stopVibration();
      
      // Aquí podrías navegar a la vista de detalles de la alerta
      // Por ahora solo marcamos que se vio
      print('👁️ Alert viewed: ${response.payload}');
    }
  }
  
  @override
  Future<void> startBackgroundService() async {
    if (!_isInitialized) await initialize();
    
    try {
      // Usar el servicio nativo de Android
      final success = await NativeBackgroundService.startService();
      
      if (success) {
        _isServiceRunning = true;
        onServiceStatusChanged(true);
        print('✅ Android background service started successfully');
      } else {
        print('❌ Failed to start Android background service');
        throw Exception('Failed to start Android background service');
      }
    } catch (e) {
      print('❌ Error starting Android background service: $e');
      rethrow;
    }
  }
  
  Future<void> _showPersistentNotification() async {
    const androidDetails = AndroidNotificationDetails(
      CHANNEL_ID,
      'Guardian Background Service',
      channelDescription: 'Escuchando alertas en tu área',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      enableVibration: false,
      playSound: false,
      icon: '@mipmap/ic_launcher',
    );
    
    const details = NotificationDetails(android: androidDetails);
    
    await _notifications.show(
      NOTIFICATION_ID,
      'Guardian Activo',
      'Escuchando alertas en tu área',
      details,
    );
  }
  
  void _startAlertsListener() {
    // Escuchar alertas de la última hora
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    
    _alertsSubscription = FirebaseFirestore.instance
        .collection('alerts')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(oneHourAgo))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final alert = AlertModel.fromFirestore(change.doc);
              onAlertReceived(alert);
            }
          }
        });
  }
  
  @override
  Future<void> stopBackgroundService() async {
    try {
      // Usar el servicio nativo de Android
      final success = await NativeBackgroundService.stopService();
      
      if (success) {
        _isServiceRunning = false;
        onServiceStatusChanged(false);
        print('✅ Android background service stopped successfully');
      } else {
        print('❌ Failed to stop Android background service');
        throw Exception('Failed to stop Android background service');
      }
    } catch (e) {
      print('❌ Error stopping Android background service: $e');
      rethrow;
    }
  }
  
  @override
  Future<bool> isServiceRunning() async {
    // Verificar con el servicio nativo
    return await NativeBackgroundService.isServiceRunning();
  }
  
  @override
  void onAlertReceived(AlertModel alert) {
    // Obtener el usuario actual
    final currentUser = _userService.currentUser;
    if (currentUser == null) return;
    
    // No mostrar notificación si la alerta fue creada por el usuario actual
    if (alert.userId != currentUser.uid) {
      // Solo mostrar notificación local en Android
      _showAlertNotification(alert);
      
      // Vibración continua como en NotificationService
      _startContinuousVibration();
      
      print('🚨 Alert received in Android background service: ${alert.alertType}');
    } else {
      print('🚨 Alert received but not showing notification (created by current user): ${alert.alertType}');
    }
  }
  
  Future<void> _showAlertNotification(AlertModel alert) async {
    const androidDetails = AndroidNotificationDetails(
      ALERTS_CHANNEL_ID,
      'Emergency Alerts',
      channelDescription: 'Alertas de emergencia en tu área',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: false, // Desactivamos vibración aquí porque usamos la continua
      playSound: true,
      enableLights: true,
      color: Color(0xFFD32F2F),
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      actions: [
        AndroidNotificationAction('view', 'Ver Detalles'),
        AndroidNotificationAction('dismiss', 'Descartar'),
      ],
    );
    
    const details = NotificationDetails(android: androidDetails);
    
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
  
  // Variables para controlar la vibración
  Timer? _vibrationTimer;
  bool _isVibrating = false;

  /// Inicia la vibración continua como en NotificationService
  Future<void> _startContinuousVibration() async {
    if (_isVibrating) return; // Evitar múltiples vibraciones simultáneas
    
    if (await Vibration.hasVibrator() ?? false) {
      _isVibrating = true;
      
      // Patrón de vibración: vibrar por 1 segundo, pausa de 0.5 segundos, repetir
      const pattern = [0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000];
      Vibration.vibrate(pattern: pattern, repeat: 2); // Repetir 2 veces
      
      // Detener la vibración después de 10 segundos
      _vibrationTimer = Timer(const Duration(seconds: 10), () {
        _stopVibration();
      });
    }
  }

  /// Detiene la vibración
  Future<void> _stopVibration() async {
    _isVibrating = false;
    _vibrationTimer?.cancel();
    Vibration.cancel();
  }

  /// Método anterior para compatibilidad
  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      // Patrón de vibración: vibrar por 1 segundo, pausa de 0.5 segundos, repetir
      const pattern = [0, 1000, 500, 1000, 500, 1000];
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
    print('🔄 Android background service status changed: $isRunning');
    // Aquí podrías notificar a la UI sobre el cambio de estado
  }
  
  @override
  Future<void> dispose() async {
    await stopBackgroundService();
    _stopVibration(); // Detener vibración al limpiar
    _isInitialized = false;
  }
}
