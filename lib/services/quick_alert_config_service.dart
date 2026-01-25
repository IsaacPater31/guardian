import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio para gestionar la configuración de destinos de quick alerts
/// Por defecto: todas las entidades (AMBIENTAL, POLICIA, BOMBEROS, TRANSITO)
/// El usuario puede agregar/quitar entidades y comunidades normales
class QuickAlertConfigService {
  static final QuickAlertConfigService _instance = QuickAlertConfigService._internal();
  factory QuickAlertConfigService() => _instance;
  QuickAlertConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _configKey = 'quick_alert_destinations';
  List<String>? _cachedDestinations;

  /// Obtiene los IDs de comunidades configuradas para recibir quick alerts
  /// Por defecto: todas las entidades
  Future<List<String>> getQuickAlertDestinations() async {
    // Si hay cache, retornarlo
    if (_cachedDestinations != null) {
      return _cachedDestinations!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(_configKey);
      
      if (savedIds != null && savedIds.isNotEmpty) {
        // Verificar que las comunidades aún existen
        final validIds = await _validateCommunityIds(savedIds);
        _cachedDestinations = validIds;
        return validIds;
      }
      
      // Si no hay configuración guardada, usar entidades por defecto
      final defaultEntities = await _getDefaultEntities();
      _cachedDestinations = defaultEntities;
      
      // Guardar por defecto
      await prefs.setStringList(_configKey, defaultEntities);
      
      return defaultEntities;
    } catch (e) {
      print('❌ Error obteniendo destinos de quick alerts: $e');
      // Fallback: retornar entidades por defecto
      return await _getDefaultEntities();
    }
  }

  /// Obtiene los IDs de todas las entidades (por defecto)
  Future<List<String>> _getDefaultEntities() async {
    try {
      final entitiesSnapshot = await _firestore
          .collection('communities')
          .where('is_entity', isEqualTo: true)
          .get();
      
      return entitiesSnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('❌ Error obteniendo entidades por defecto: $e');
      return [];
    }
  }

  /// Valida que los IDs de comunidades existan
  Future<List<String>> _validateCommunityIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    final validIds = <String>[];
    
    // Validar en lotes de 10 (límite de Firestore whereIn)
    for (int i = 0; i < ids.length; i += 10) {
      final batch = ids.skip(i).take(10).toList();
      final snapshot = await _firestore
          .collection('communities')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      
      validIds.addAll(snapshot.docs.map((doc) => doc.id));
    }
    
    return validIds;
  }

  /// Actualiza la configuración de destinos de quick alerts
  Future<bool> updateQuickAlertDestinations(List<String> communityIds) async {
    try {
      // Validar que las comunidades existen
      final validIds = await _validateCommunityIds(communityIds);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_configKey, validIds);
      
      // Actualizar cache
      _cachedDestinations = validIds;
      
      print('✅ Configuración de quick alerts actualizada: ${validIds.length} destinos');
      return true;
    } catch (e) {
      print('❌ Error actualizando destinos de quick alerts: $e');
      return false;
    }
  }

  /// Obtiene todas las comunidades disponibles para configurar (entidades + comunidades del usuario)
  Future<List<Map<String, dynamic>>> getAvailableDestinations() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      // Obtener todas las comunidades del usuario
      final membersSnapshot = await _firestore
          .collection('community_members')
          .where('user_id', isEqualTo: userId)
          .get();

      if (membersSnapshot.docs.isEmpty) return [];

      final communityIds = membersSnapshot.docs
          .map((doc) => doc.data()['community_id'] as String)
          .toList();

      if (communityIds.isEmpty) return [];

      final List<Map<String, dynamic>> communities = [];

      // Obtener información de las comunidades en lotes
      for (int i = 0; i < communityIds.length; i += 10) {
        final batch = communityIds.skip(i).take(10).toList();
        final communitiesSnapshot = await _firestore
            .collection('communities')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        communities.addAll(
          communitiesSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'],
              'description': data['description'],
              'is_entity': data['is_entity'] ?? false,
            };
          }),
        );
      }

      // Ordenar: entidades primero, luego comunidades normales
      communities.sort((a, b) {
        if (a['is_entity'] == b['is_entity']) {
          return (a['name'] as String).compareTo(b['name'] as String);
        }
        return (b['is_entity'] as bool) ? 1 : -1;
      });

      return communities;
    } catch (e) {
      print('❌ Error obteniendo destinos disponibles: $e');
      return [];
    }
  }

  /// Invalida el cache (llamar cuando se actualiza la configuración)
  void invalidateCache() {
    _cachedDestinations = null;
  }
}
