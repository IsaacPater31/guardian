import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/emergency_types.dart';

/// Servicio para gestionar las comunidades por defecto de cada tipo de alerta
/// (las que se arrastran en el menú radial).
///
/// Almacena la configuración en SharedPreferences con claves del tipo:
///   swipe_alert_communities_HEALTH          → ["communityId1", "communityId2"]
///   swipe_alert_communities_POLICE          → ["communityId3"]
///   etc.
///
/// Cuando no hay configuración guardada para un tipo, devuelve null para que
/// la UI pueda redirigir al usuario a la pantalla de configuración.
class SwipeAlertConfigService {
  static final SwipeAlertConfigService _instance =
      SwipeAlertConfigService._internal();
  factory SwipeAlertConfigService() => _instance;
  SwipeAlertConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _keyPrefix = 'swipe_alert_communities_';

  // Cache en memoria para evitar tocar SharedPreferences en cada swipe
  final Map<String, List<String>?> _cache = {};

  /// Devuelve los IDs de comunidades configurados para [alertType].
  /// Retorna null si no hay ninguno configurado (→ mostrar aviso de config).
  Future<List<String>?> getCommunitiesForType(String alertType) async {
    if (_cache.containsKey(alertType)) {
      return _cache[alertType];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('$_keyPrefix$alertType');

      if (saved == null || saved.isEmpty) {
        _cache[alertType] = null;
        return null;
      }

      // Validar que los IDs aún existen (puede que el usuario salió de la comunidad)
      final valid = await _validateCommunityIds(saved);
      _cache[alertType] = valid.isEmpty ? null : valid;
      return _cache[alertType];
    } catch (e) {
      print('❌ SwipeAlertConfigService.getCommunitiesForType: $e');
      return null;
    }
  }

  /// Guarda los IDs de comunidades para [alertType].
  Future<bool> setCommunitiesForType(
      String alertType, List<String> communityIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('$_keyPrefix$alertType', communityIds);
      _cache[alertType] = communityIds.isEmpty ? null : communityIds;
      print('✅ SwipeAlertConfig [$alertType] → ${communityIds.length} comunidad(es)');
      return true;
    } catch (e) {
      print('❌ SwipeAlertConfigService.setCommunitiesForType: $e');
      return false;
    }
  }

  /// Inicializa la configuración por defecto para los tipos que tienen un
  /// [defaultCommunityKeyword] definido en [EmergencyTypes].
  /// Solo se ejecuta si el tipo aún no tiene configuración guardada.
  /// Debe llamarse después de que las comunidades del usuario estén cargadas.
  Future<void> initDefaults(List<Map<String, dynamic>> communities) async {
    for (final entry in EmergencyTypes.types.entries) {
      final typeName = entry.value['type'] as String;
      final keyword = entry.value['defaultCommunityKeyword'] as String?;
      if (keyword == null) continue;

      // Solo inicializar si no hay nada guardado
      final existing = await getCommunitiesForType(typeName);
      if (existing != null) continue;

      // Buscar comunidades cuyo nombre contenga el keyword
      final matched = communities
          .where((c) {
            final name = (c['name'] as String? ?? '').toUpperCase();
            return name.contains(keyword);
          })
          .map((c) => c['id'] as String)
          .toList();

      if (matched.isNotEmpty) {
        await setCommunitiesForType(typeName, matched);
        print('🔧 Default para $typeName → $matched');
      }
    }
  }

  /// Obtiene todas las comunidades del usuario disponibles para configurar
  Future<List<Map<String, dynamic>>> getAvailableCommunities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final membersSnapshot = await _firestore
          .collection('community_members')
          .where('user_id', isEqualTo: userId)
          .get();

      if (membersSnapshot.docs.isEmpty) return [];

      final communityIds = membersSnapshot.docs
          .map((doc) => doc.data()['community_id'] as String)
          .toList();

      final List<Map<String, dynamic>> communities = [];

      for (int i = 0; i < communityIds.length; i += 10) {
        final batch = communityIds.skip(i).take(10).toList();
        final snap = await _firestore
            .collection('communities')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        communities.addAll(snap.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'description': data['description'],
            'is_entity': data['is_entity'] ?? false,
            'icon_code_point': data['icon_code_point'],
            'icon_color': data['icon_color'],
          };
        }));
      }

      // Entidades primero, luego orden alfabético
      communities.sort((a, b) {
        if (a['is_entity'] == b['is_entity']) {
          return (a['name'] as String).compareTo(b['name'] as String);
        }
        return (b['is_entity'] as bool) ? 1 : -1;
      });

      return communities;
    } catch (e) {
      print('❌ SwipeAlertConfigService.getAvailableCommunities: $e');
      return [];
    }
  }

  /// Invalida el cache completo (llamar cuando el usuario cambia comunidades)
  void invalidateCache() {
    _cache.clear();
  }

  /// Valida que los IDs aún existen en Firestore
  Future<List<String>> _validateCommunityIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final valid = <String>[];
    for (int i = 0; i < ids.length; i += 10) {
      final batch = ids.skip(i).take(10).toList();
      final snap = await _firestore
          .collection('communities')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      valid.addAll(snap.docs.map((d) => d.id));
    }
    return valid;
  }
}
