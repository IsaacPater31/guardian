import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';
import 'user_service.dart';
import 'community_service.dart';

class AlertRepository {
  static final AlertRepository _instance = AlertRepository._internal();
  factory AlertRepository() => _instance;
  AlertRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();
  final CommunityService _communityService = CommunityService();
  
  // Cache de IDs de comunidades del usuario (se actualiza periódicamente)
  List<String>? _cachedUserCommunityIds;
  DateTime? _cacheTimestamp;
  static const _cacheValidityDuration = Duration(minutes: 5);

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

  /// Reporta una alerta (multi-reporte). Un usuario solo puede reportar una vez por alerta.
  /// Lanza [Exception] si el usuario no está autenticado, la alerta no existe o ya fue reportada.
  Future<void> reportAlert(String alertId) async {
    final currentUser = _userService.currentUser;
    if (currentUser == null) {
      throw Exception('Usuario no autenticado');
    }

    final alertRef = _firestore.collection('alerts').doc(alertId);

    await _firestore.runTransaction((transaction) async {
      final alertDoc = await transaction.get(alertRef);
      if (!alertDoc.exists) {
        throw Exception('Alerta no encontrada');
      }

      final data = alertDoc.data() ?? {};
      final reportedBy = List<String>.from(data['reported_by'] ?? []);
      final reportsCount = (data['reports_count'] as int?) ?? 0;

      if (reportedBy.contains(currentUser.uid)) {
        throw Exception('Ya has reportado esta alerta');
      }

      reportedBy.add(currentUser.uid);
      transaction.update(alertRef, {
        'reported_by': reportedBy,
        'reports_count': reportsCount + 1,
      });
    });
  }

  /// Obtiene los IDs de comunidades del usuario (con cache)
  Future<List<String>> _getUserCommunityIds() async {
    // Verificar cache
    if (_cachedUserCommunityIds != null && 
        _cacheTimestamp != null && 
        DateTime.now().difference(_cacheTimestamp!) < _cacheValidityDuration) {
      return _cachedUserCommunityIds!;
    }
    
    try {
      final communities = await _communityService.getMyCommunities();
      final communityIds = communities.map((c) => c['id'] as String).toList();
      
      // Actualizar cache
      _cachedUserCommunityIds = communityIds;
      _cacheTimestamp = DateTime.now();
      
      return communityIds;
    } catch (e) {
      print('❌ Error obteniendo IDs de comunidades: $e');
      return _cachedUserCommunityIds ?? [];
    }
  }
  
  /// Invalida el cache de comunidades (llamar cuando el usuario se une/abandona una comunidad)
  void invalidateCommunityCache() {
    _cachedUserCommunityIds = null;
    _cacheTimestamp = null;
  }

  /// Cuenta alertas no leídas por comunidad (últimas 24h). Una alerta es "no leída" si el usuario actual no está en viewedBy.
  /// Retorna Map<communityId, count>. Reutiliza la misma query que getRecentAlerts para no hacer reads extra.
  Future<Map<String, int>> getUnreadCountByCommunity() async {
    try {
      final alerts = await getRecentAlerts();
      final uid = _userService.currentUser?.uid;
      if (uid == null) return {};

      final Map<String, int> counts = {};
      for (final alert in alerts) {
        if (alert.communityId == null || alert.communityId!.isEmpty) continue;
        final viewed = alert.viewedBy.contains(uid);
        if (!viewed) {
          counts[alert.communityId!] = (counts[alert.communityId!] ?? 0) + 1;
        }
      }
      return counts;
    } catch (e) {
      print('Error getUnreadCountByCommunity: $e');
      return {};
    }
  }

  /// Obtiene alertas recientes (últimas 24 horas)
  /// Filtra por comunidades del usuario (Iteración 2.5)
  Future<List<AlertModel>> getRecentAlerts() async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      
      final snapshot = await _firestore
          .collection('alerts')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .orderBy('timestamp', descending: true)
          .get();
      
      final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
      
      // Obtener IDs de comunidades del usuario
      final userCommunityIds = await _getUserCommunityIds();
      
      // Filtrar alertas:
      // 1. Según permisos del usuario
      // 2. Si tiene community_id: solo si el usuario es miembro de esa comunidad
      // 3. Si NO tiene community_id: mantener comportamiento legacy (mostrar a todos)
      final filteredAlerts = allAlerts.where((alert) {
        // Verificar permisos básicos
        if (!_userService.canUserViewAlert(
          alert.userId, 
          alert.userEmail, 
          alert.isAnonymous
        )) {
          return false;
        }
        
        // Si la alerta tiene community_id, verificar membresía
        if (alert.communityId != null && alert.communityId!.isNotEmpty) {
          return userCommunityIds.contains(alert.communityId);
        }
        
        // Alerta sin community_id (legacy) - mantener comportamiento anterior
        return true;
      }).toList();
      
      return filteredAlerts;
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
  /// Filtra por comunidades del usuario (Iteración 2.5)
  Stream<List<AlertModel>> getRecentAlertsStream() {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    
    return _firestore
        .collection('alerts')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
          
          // Obtener IDs de comunidades del usuario (con cache)
          final userCommunityIds = await _getUserCommunityIds();
          
          // Filtrar alertas:
          // 1. Según permisos del usuario
          // 2. Si tiene community_id: solo si el usuario es miembro de esa comunidad
          // 3. Si NO tiene community_id: mantener comportamiento legacy (mostrar a todos)
          return allAlerts.where((alert) {
            // Verificar permisos básicos
            if (!_userService.canUserViewAlert(
              alert.userId, 
              alert.userEmail, 
              alert.isAnonymous
            )) {
              return false;
            }
            
            // Si la alerta tiene community_id, verificar membresía
            if (alert.communityId != null && alert.communityId!.isNotEmpty) {
              return userCommunityIds.contains(alert.communityId);
            }
            
            // Alerta sin community_id (legacy) - mantener comportamiento anterior
            return true;
          }).toList();
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

  /// Obtiene alertas de una comunidad específica
  /// Nota: Ordena en memoria para evitar requerir índice compuesto en Firestore (plan gratuito)
  Future<List<AlertModel>> getCommunityAlerts(String communityId) async {
    try {
      // Query sin orderBy para evitar requerir índice compuesto
      final snapshot = await _firestore
          .collection('alerts')
          .where('community_id', isEqualTo: communityId)
          .get();
      
      final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
      
      // Filtrar alertas según permisos del usuario
      final filteredAlerts = allAlerts.where((alert) => _userService.canUserViewAlert(
        alert.userId, 
        alert.userEmail, 
        alert.isAnonymous
      )).toList();
      
      // Ordenar en memoria por timestamp (más reciente primero) y limitar a 50
      filteredAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return filteredAlerts.take(50).toList();
    } catch (e) {
      print('Error getting community alerts: $e');
      return [];
    }
  }

  /// Obtiene un stream de alertas de una comunidad específica
  /// Nota: Ordena en memoria para evitar requerir índice compuesto en Firestore (plan gratuito)
  Stream<List<AlertModel>> getCommunityAlertsStream(String communityId) {
    return _firestore
        .collection('alerts')
        .where('community_id', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
          
          // Filtrar alertas según permisos del usuario
          final filteredAlerts = allAlerts.where((alert) => _userService.canUserViewAlert(
            alert.userId, 
            alert.userEmail, 
            alert.isAnonymous
          )).toList();
          
          // Ordenar en memoria por timestamp (más reciente primero) y limitar a 50
          filteredAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return filteredAlerts.take(50).toList();
        });
  }
}
