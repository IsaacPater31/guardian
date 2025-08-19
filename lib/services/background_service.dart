import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import '../models/alert_model.dart';
import 'background/background_service_factory.dart';
import 'background/background_service_interface.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  
  // Servicio específico de la plataforma
  BackgroundServiceInterface? _platformService;
  bool _isInitialized = false;

  /// Inicializa los servicios en segundo plano
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Crear el servicio específico de la plataforma
      _platformService = BackgroundServiceFactory.createService();
      
      // Inicializar el servicio de la plataforma
      await _platformService!.initialize();
      
      _isInitialized = true;
      print('✅ Background service initialized for platform: ${BackgroundServiceFactory.getPlatformCapabilities()['platform']}');
    } catch (e) {
      print('❌ Error initializing background service: $e');
      rethrow;
    }
  }

  /// Inicia el monitoreo en segundo plano
  Future<void> startBackgroundMonitoring() async {
    if (!_isInitialized) await initialize();
    
    try {
      await _platformService!.startBackgroundService();
      print('✅ Background monitoring started successfully');
    } catch (e) {
      print('❌ Error starting background monitoring: $e');
      rethrow;
    }
  }

  /// Detiene el monitoreo en segundo plano
  Future<void> stopBackgroundMonitoring() async {
    if (!_isInitialized || _platformService == null) return;
    
    try {
      await _platformService!.stopBackgroundService();
      print('✅ Background monitoring stopped successfully');
    } catch (e) {
      print('❌ Error stopping background monitoring: $e');
      rethrow;
    }
  }

  /// Verifica el estado del monitoreo en segundo plano
  Future<Map<String, dynamic>> getBackgroundStatus() async {
    if (!_isInitialized || _platformService == null) {
      return {
        'status': 'not_initialized',
        'message': 'Background service not initialized',
      };
    }
    
    try {
      final isRunning = await _platformService!.isServiceRunning();
      final capabilities = BackgroundServiceFactory.getPlatformCapabilities();
      
      return {
        'status': isRunning ? 'running' : 'stopped',
        'platform': capabilities['platform'],
        'capabilities': capabilities,
        'message': isRunning 
          ? 'Background monitoring is active'
          : 'Background monitoring is stopped',
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Error checking background status: $e',
      };
    }
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
  
  /// Verifica si el servicio está ejecutándose
  Future<bool> isServiceRunning() async {
    if (!_isInitialized || _platformService == null) return false;
    return await _platformService!.isServiceRunning();
  }
  
  /// Obtiene las capacidades de la plataforma actual
  Map<String, dynamic> getPlatformCapabilities() {
    return BackgroundServiceFactory.getPlatformCapabilities();
  }
  
  /// Limpia recursos del servicio
  Future<void> dispose() async {
    if (_platformService != null) {
      await _platformService!.dispose();
    }
    _isInitialized = false;
  }
} 