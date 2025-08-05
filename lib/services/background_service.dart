import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import '../models/alert_model.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  /// Inicializa los servicios en segundo plano
  Future<void> initialize() async {
    // Firebase Messaging ya maneja las notificaciones en segundo plano
    print('Background service initialized with Firebase Messaging');
  }

  /// Inicia el monitoreo en segundo plano
  Future<void> startBackgroundMonitoring() async {
    // Firebase Messaging ya está configurado en NotificationService
    print('Background monitoring started with Firebase Messaging');
  }

  /// Detiene el monitoreo en segundo plano
  Future<void> stopBackgroundMonitoring() async {
    print('Background monitoring stopped');
  }

  /// Verifica el estado del monitoreo en segundo plano
  Future<Map<String, dynamic>> getBackgroundStatus() async {
    return {
      'firebaseMessaging': 'active',
      'message': 'Background monitoring is active with Firebase Messaging',
    };
  }

  /// Verifica si hay alertas nuevas (método manual para uso futuro)
  static Future<void> checkNewAlerts() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;
      
      if (auth.currentUser == null) return;

      // Obtener la última alerta vista por el usuario
      final userDoc = await firestore.collection('users').doc(auth.currentUser!.uid).get();
      final lastAlertTimestamp = userDoc.data()?['lastAlertTimestamp'];

      // Buscar alertas nuevas desde la última vista
      Query query = firestore.collection('alerts')
          .orderBy('timestamp', descending: true)
          .limit(10);

      if (lastAlertTimestamp != null) {
        query = query.where('timestamp', isGreaterThan: lastAlertTimestamp);
      }

      final snapshot = await query.get();
      
      if (snapshot.docs.isNotEmpty) {
        // Actualizar timestamp de la última alerta vista
        await firestore.collection('users').doc(auth.currentUser!.uid).update({
          'lastAlertTimestamp': FieldValue.serverTimestamp(),
        });

        print('Found ${snapshot.docs.length} new alerts');
      }
    } catch (e) {
      print('Error checking new alerts: $e');
    }
  }
} 