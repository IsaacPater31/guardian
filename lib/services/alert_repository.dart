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
    if (_cachedUserCommunityIds != null && 
        _cacheTimestamp != null && 
        DateTime.now().difference(_cacheTimestamp!) < _cacheValidityDuration) {
      return _cachedUserCommunityIds!;
    }
    
    try {
      final communities = await _communityService.getMyCommunities();
      final communityIds = communities.map((c) => c['id'] as String).toList();
      _cachedUserCommunityIds = communityIds;
      _cacheTimestamp = DateTime.now();
      return communityIds;
    } catch (e) {
      print('❌ Error obteniendo IDs de comunidades: $e');
      return _cachedUserCommunityIds ?? [];
    }
  }
  
  /// Invalida el cache de comunidades
  void invalidateCommunityCache() {
    _cachedUserCommunityIds = null;
    _cacheTimestamp = null;
  }

  /// Cuenta alertas no leídas por comunidad (últimas 24h).
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
  Future<List<AlertModel>> getRecentAlerts() async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      
      final snapshot = await _firestore
          .collection('alerts')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .orderBy('timestamp', descending: true)
          .get();
      
      final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
      final userCommunityIds = await _getUserCommunityIds();
      
      return allAlerts.where((alert) {
        if (!_userService.canUserViewAlert(alert.userId, alert.userEmail, alert.isAnonymous)) {
          return false;
        }
        if (alert.communityId != null && alert.communityId!.isNotEmpty) {
          return userCommunityIds.contains(alert.communityId);
        }
        return true;
      }).toList();
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
      
      return allAlerts.where((alert) {
        if (!alert.shareLocation || alert.location == null) return false;
        return _userService.canUserViewAlert(alert.userId, alert.userEmail, alert.isAnonymous);
      }).toList();
    } catch (e) {
      print('Error getting map alerts: $e');
      return [];
    }
  }

  // ─── NUEVO: Obtiene alertas del mapa con filtros aplicados en Firestore ───

  /// Calcula el rango de fechas para un preset dado.
  static ({DateTime start, DateTime? end}) _getDateRange(String range) {
    final now = DateTime.now();
    switch (range) {
      case 'today':
        return (
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case 'yesterday':
        final y = now.subtract(const Duration(days: 1));
        return (
          start: DateTime(y.year, y.month, y.day),
          end: DateTime(y.year, y.month, y.day, 23, 59, 59),
        );
      case 'week':
        // Lunes de esta semana
        final offset = now.weekday - 1;
        final monday = now.subtract(Duration(days: offset));
        return (
          start: DateTime(monday.year, monday.month, monday.day),
          end: null,
        );
      case '7days':
        return (
          start: now.subtract(const Duration(days: 6)),
          end: null,
        );
      case 'month':
        return (
          start: DateTime(now.year, now.month, 1),
          end: null,
        );
      default:
        return (
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: null,
        );
    }
  }

  /// Stream de alertas del mapa con filtros activos.
  ///
  /// Parámetros:
  ///   [selectedTypes] — lista de alertType (vacía = todos los tipos)
  ///   [filterStatus]  — 'all' | 'pending' | 'attended'
  ///   [filterDateRange] — 'all' | 'today' | 'yesterday' | 'week' | '7days' | 'month' | 'custom'
  ///   [customStart] / [customEnd] — para rango personalizado
  ///
  /// Estrategia de query (evita índices compuestos en plan gratuito):
  ///   - Un solo tipo → where alertType == T + where timestamp en rango
  ///   - Múltiples tipos o sin filtro de tipo → where timestamp en rango;
  ///     el filtro de alertType se aplica en memoria (post-fetch)
  ///   - El filtro de estado (alertStatus) siempre en memoria (no soporta ≠ en plan gratuito)
  Stream<List<AlertModel>> getMapAlertsStreamFiltered({
    List<String> selectedTypes = const [],
    String filterStatus = 'all',
    String filterDateRange = 'all',
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final hasType = selectedTypes.isNotEmpty;
    final hasDate = filterDateRange != 'all';
    final hasStatus = filterStatus != 'all';

    DateTime? start;
    DateTime? end;

    if (hasDate) {
      if (filterDateRange == 'custom') {
        start = customStart;
        end = customEnd;
      } else {
        final range = _getDateRange(filterDateRange);
        start = range.start;
        end = range.end;
      }
    } else {
      // Sin filtro de fecha: últimos 7 días por defecto
      start = DateTime.now().subtract(const Duration(days: 7));
    }

    // Construir la query base
    Query<Map<String, dynamic>> q = _firestore.collection('alerts');

    if (hasType && selectedTypes.length == 1) {
      // Un solo tipo: filtro server-side en alertType + timestamp (requiere índice simple)
      q = q.where('alertType', isEqualTo: selectedTypes.first);
      if (start != null) q = q.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      if (end != null) q = q.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end));
      q = q.orderBy('timestamp', descending: true);
    } else {
      // Sin filtro de tipo, o múltiples tipos: filtrar por timestamp server-side
      if (start != null) q = q.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      if (end != null) q = q.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end));
      q = q.orderBy('timestamp', descending: true);
    }

    return q.snapshots().map((snapshot) {
      List<AlertModel> alerts = snapshot.docs
          .map((doc) => AlertModel.fromFirestore(doc))
          .toList();

      // Filtros en memoria (baratos, ya reducidos por la query server-side)

      // 1. Solo alertas con ubicación
      alerts = alerts.where((a) => a.shareLocation && a.location != null).toList();

      // 2. Permisos del usuario
      alerts = alerts.where((a) => _userService.canUserViewAlert(
        a.userId, a.userEmail, a.isAnonymous,
      )).toList();

      // 3. Múltiples tipos (cuando la query no pudo filtrar server-side)
      if (hasType && selectedTypes.length > 1) {
        alerts = alerts.where((a) => selectedTypes.contains(a.alertType)).toList();
      }

      // 4. Estado de atención
      if (hasStatus) {
        alerts = alerts.where((a) {
          if (filterStatus == 'attended') return a.alertStatus == 'attended';
          return a.alertStatus != 'attended'; // pending / null
        }).toList();
      }

      return alerts;
    });
  }

  /// Obtiene un stream de alertas recientes (últimas 24h)
  Stream<List<AlertModel>> getRecentAlertsStream() {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    
    return _firestore
        .collection('alerts')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
          final userCommunityIds = await _getUserCommunityIds();
          
          return allAlerts.where((alert) {
            if (!_userService.canUserViewAlert(alert.userId, alert.userEmail, alert.isAnonymous)) {
              return false;
            }
            if (alert.communityId != null && alert.communityId!.isNotEmpty) {
              return userCommunityIds.contains(alert.communityId);
            }
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
          return allAlerts.where((alert) {
            if (!alert.shareLocation || alert.location == null) return false;
            return _userService.canUserViewAlert(alert.userId, alert.userEmail, alert.isAnonymous);
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

  /// Obtiene un stream de alertas PROPIAS del usuario en una comunidad.
  Stream<List<AlertModel>> getOwnAlertsStream(String communityId, String uid) {
    return _firestore
        .collection('alerts')
        .where('community_id', isEqualTo: communityId)
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final alerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
          alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return alerts;
        });
  }

  /// Obtiene un stream de alertas DE OTROS en una comunidad.
  Stream<List<AlertModel>> getOthersAlertsStream(String communityId, String uid) {
    return _firestore
        .collection('alerts')
        .where('community_id', isEqualTo: communityId)
        .where('userId', isNotEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final alerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
          alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return alerts;
        });
  }

  /// Actualiza el estado de una alerta. Solo para usuarios con rol 'official'.
  Future<void> updateAlertStatus(String alertId, String status) async {
    try {
      await _firestore
          .collection('alerts')
          .doc(alertId)
          .update({'alert_status': status});
    } catch (e) {
      print('Error updating alert status: $e');
      rethrow;
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
  Future<List<AlertModel>> getCommunityAlerts(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('alerts')
          .where('community_id', isEqualTo: communityId)
          .get();
      
      final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
      final filteredAlerts = allAlerts.where((alert) => _userService.canUserViewAlert(
        alert.userId, alert.userEmail, alert.isAnonymous,
      )).toList();
      
      filteredAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return filteredAlerts.take(50).toList();
    } catch (e) {
      print('Error getting community alerts: $e');
      return [];
    }
  }

  /// Obtiene un stream de alertas de una comunidad específica
  Stream<List<AlertModel>> getCommunityAlertsStream(String communityId) {
    return _firestore
        .collection('alerts')
        .where('community_id', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          final allAlerts = snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
          final filteredAlerts = allAlerts.where((alert) => _userService.canUserViewAlert(
            alert.userId, alert.userEmail, alert.isAnonymous,
          )).toList();
          filteredAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return filteredAlerts.take(50).toList();
        });
  }
}
