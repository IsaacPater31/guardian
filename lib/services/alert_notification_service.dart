import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/alert_model.dart';

class AlertNotificationService {
  static final AlertNotificationService _instance = AlertNotificationService._internal();
  factory AlertNotificationService() => _instance;
  AlertNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Envía notificaciones push cuando se crea una nueva alerta
  Future<void> sendAlertNotification(AlertModel alert) async {
    try {
      // Obtener todos los tokens FCM de usuarios (excepto el que creó la alerta)
      final usersSnapshot = await _firestore.collection('users').get();
      final tokens = <String>[];
      
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final fcmToken = userData['fcmToken'] as String?;
        final userId = userDoc.id;
        
        // No enviar notificación al usuario que creó la alerta
        if (fcmToken != null && userId != alert.userId) {
          tokens.add(fcmToken);
        }
      }

      if (tokens.isNotEmpty) {
        // Enviar notificación a todos los usuarios
        await _sendPushNotification(tokens, alert);
      }
    } catch (e) {
      print('Error sending alert notification: $e');
    }
  }

  /// Envía la notificación push usando Firebase Cloud Messaging
  Future<void> _sendPushNotification(List<String> tokens, AlertModel alert) async {
    try {
      // Crear el mensaje de notificación
      final message = {
        'notification': {
          'title': _getAlertTitle(alert),
          'body': _getAlertBody(alert),
        },
        'data': {
          'alertId': alert.id ?? '',
          'alertType': alert.alertType,
          'timestamp': alert.timestamp.toIso8601String(),
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'android': {
          'notification': {
            'channel_id': 'emergency_alerts',
            'priority': 'high',
            'default_sound': true,
            'default_vibrate_timings': true,
            'default_light_settings': true,
            'color': '#D32F2F',
          },
        },
        'apns': {
          'payload': {
            'aps': {
              'sound': 'default',
              'badge': 1,
              'alert': {
                'title': _getAlertTitle(alert),
                'body': _getAlertBody(alert),
              },
            },
          },
        },
        'tokens': tokens,
      };

      // Enviar usando Firebase Functions (recomendado) o directamente
      // Por ahora, usaremos un enfoque directo con Firestore
      await _firestore.collection('notifications').add({
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

    } catch (e) {
      print('Error sending push notification: $e');
    }
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

  /// Suscribe a un usuario al topic de alertas
  Future<void> subscribeUserToAlerts(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'subscribedToAlerts': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error subscribing user to alerts: $e');
    }
  }

  /// Desuscribe a un usuario del topic de alertas
  Future<void> unsubscribeUserFromAlerts(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'subscribedToAlerts': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error unsubscribing user from alerts: $e');
    }
  }

  /// Verifica si un usuario está suscrito a las alertas
  Future<bool> isUserSubscribedToAlerts(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['subscribedToAlerts'] ?? false;
    } catch (e) {
      print('Error checking user subscription: $e');
      return false;
    }
  }
} 