import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/alert_model.dart';

class MapController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Stream<List<AlertModel>> getAlertsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    // Obtener alertas de los últimos 7 días
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    
    return _firestore
        .collection('alerts')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
          
          // Filtrar alertas: no mostrar las propias y solo las que compartan ubicación
          return allAlerts.where((alert) {
            // Si la alerta no comparte ubicación, no mostrarla
            if (!alert.shareLocation || alert.location == null) {
              return false;
            }
            
            // Si la alerta es anónima, siempre mostrarla
            if (alert.isAnonymous) {
              return true;
            }
            
            // Si la alerta tiene userId y coincide con el usuario actual, no mostrarla
            if (alert.userId != null && alert.userId == currentUser.uid) {
              return false;
            }
            
            // Si la alerta tiene userEmail y coincide con el usuario actual, no mostrarla
            if (alert.userEmail != null && alert.userEmail == currentUser.email) {
              return false;
            }
            
            return true;
          }).toList();
        });
  }

  Future<List<AlertModel>> getAlertsOnce() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      // Obtener alertas de los últimos 7 días
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final snapshot = await _firestore
          .collection('alerts')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .orderBy('timestamp', descending: true)
          .get();

      final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
      
      // Filtrar alertas: no mostrar las propias y solo las que compartan ubicación
      return allAlerts.where((alert) {
        // Si la alerta no comparte ubicación, no mostrarla
        if (!alert.shareLocation || alert.location == null) {
          return false;
        }
        
        // Si la alerta es anónima, siempre mostrarla
        if (alert.isAnonymous) {
          return true;
        }
        
        // Si la alerta tiene userId y coincide con el usuario actual, no mostrarla
        if (alert.userId != null && alert.userId == currentUser.uid) {
          return false;
        }
        
        // Si la alerta tiene userEmail y coincide con el usuario actual, no mostrarla
        if (alert.userEmail != null && alert.userEmail == currentUser.email) {
          return false;
        }
        
        return true;
      }).toList();
    } catch (e) {
      print('Error loading alerts: $e');
      return [];
    }
  }
} 