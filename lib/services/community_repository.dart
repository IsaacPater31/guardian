import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_model.dart';

/// Repositorio para operaciones CRUD de comunidades
/// Estructura básica - se implementará en iteraciones siguientes
class CommunityRepository {
  static final CommunityRepository _instance = CommunityRepository._internal();
  factory CommunityRepository() => _instance;
  CommunityRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtiene una comunidad por ID
  Future<CommunityModel?> getCommunityById(String communityId) async {
    try {
      final doc = await _firestore.collection('communities').doc(communityId).get();
      if (!doc.exists) return null;
      return CommunityModel.fromFirestore(doc);
    } catch (e) {
      print('❌ Error obteniendo comunidad: $e');
      return null;
    }
  }

  /// Actualiza una comunidad
  Future<bool> updateCommunity(String communityId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('communities').doc(communityId).update(data);
      return true;
    } catch (e) {
      print('❌ Error actualizando comunidad: $e');
      return false;
    }
  }

  /// Elimina una comunidad por ID (sin validaciones - usar CommunityService.deleteCommunity para validación de creador)
  Future<bool> deleteCommunity(String communityId) async {
    try {
      await _firestore.collection('communities').doc(communityId).delete();
      return true;
    } catch (e) {
      print('❌ Error eliminando comunidad: $e');
      return false;
    }
  }

  /// Obtiene todas las comunidades (para uso administrativo)
  Future<List<CommunityModel>> getAllCommunities() async {
    try {
      final snapshot = await _firestore.collection('communities').get();
      return snapshot.docs
          .map((doc) => CommunityModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo comunidades: $e');
      return [];
    }
  }
}

