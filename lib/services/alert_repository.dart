import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';
import 'user_service.dart';

class AlertRepository {
  static final AlertRepository _instance = AlertRepository._internal();
  factory AlertRepository() => _instance;
  AlertRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();

  /// Guarda una alerta en Firestore
  Future<String> saveAlert(AlertModel alert) async {
    try {
      final docRef = await _firestore.collection('alerts').add(alert.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error saving alert: $e');
      rethrow;
    }
  }

  /// Actualiza una alerta existente
  Future<void> updateAlert(String alertId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('alerts').doc(alertId).update(data);
    } catch (e) {
      print('Error updating alert: $e');
      rethrow;
    }
  }

  /// Marca una alerta como vista por el usuario actual
  Future<void> markAlertAsViewed(String alertId) async {
    try {
      final currentUser = _userService.currentUser;
      if (currentUser == null) return;

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
    } catch (e) {
      print('Error marking alert as viewed: $e');
      rethrow;
    }
  }

  /// Obtiene alertas recientes (últimas 24 horas)
  Future<List<AlertModel>> getRecentAlerts() async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      
      final snapshot = await _firestore
          .collection('alerts')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .orderBy('timestamp', descending: true)
          .get();
      
      final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
      
      // Filtrar alertas según permisos del usuario
      return allAlerts.where((alert) => _userService.canUserViewAlert(
        alert.userId, 
        alert.userEmail, 
        alert.isAnonymous
      )).toList();
    } catch (e) {
      print('Error getting recent alerts: $e');
      return [];
    }
  }

  /// Obtiene alertas para el mapa (últimos 7 días con ubicación)
  Future<List<AlertModel>> getMapAlerts() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final snapshot = await _firestore
          .collection('alerts')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .orderBy('timestamp', descending: true)
          .get();

      final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
      
      // Filtrar: solo alertas con ubicación y según permisos del usuario
      return allAlerts.where((alert) {
        // Solo alertas que compartan ubicación
        if (!alert.shareLocation || alert.location == null) {
          return false;
        }
        
        // Verificar permisos del usuario
        return _userService.canUserViewAlert(
          alert.userId, 
          alert.userEmail, 
          alert.isAnonymous
        );
      }).toList();
    } catch (e) {
      print('Error getting map alerts: $e');
      return [];
    }
  }

  /// Obtiene un stream de alertas recientes
  Stream<List<AlertModel>> getRecentAlertsStream() {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    
    return _firestore
        .collection('alerts')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
          
          // Filtrar alertas según permisos del usuario
          return allAlerts.where((alert) => _userService.canUserViewAlert(
            alert.userId, 
            alert.userEmail, 
            alert.isAnonymous
          )).toList();
        });
  }

  /// Obtiene un stream de alertas para el mapa
  Stream<List<AlertModel>> getMapAlertsStream() {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    
    return _firestore
        .collection('alerts')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
          
          // Filtrar: solo alertas con ubicación y según permisos del usuario
          return allAlerts.where((alert) {
            // Solo alertas que compartan ubicación
            if (!alert.shareLocation || alert.location == null) {
              return false;
            }
            
            // Verificar permisos del usuario
            return _userService.canUserViewAlert(
              alert.userId, 
              alert.userEmail, 
              alert.isAnonymous
            );
          }).toList();
        });
  }

  /// Obtiene estadísticas de alertas
  Future<Map<String, int>> getAlertStatistics() async {
    try {
      final alerts = await getRecentAlerts();
      final stats = <String, int>{};
      
      for (final alert in alerts) {
        stats[alert.alertType] = (stats[alert.alertType] ?? 0) + 1;
      }
      
      return stats;
    } catch (e) {
      print('Error getting alert statistics: $e');
      return {};
    }
  }

  /// Obtiene estadísticas de vistas
  Future<Map<String, int>> getViewStatistics() async {
    try {
      final alerts = await getRecentAlerts();
      final stats = <String, int>{};
      
      for (final alert in alerts) {
        stats[alert.alertType] = (stats[alert.alertType] ?? 0) + alert.viewedCount;
      }
      
      return stats;
    } catch (e) {
      print('Error getting view statistics: $e');
      return {};
    }
  }
}
