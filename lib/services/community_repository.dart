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

  // Más métodos se agregarán en iteraciones siguientes:
  // - createCommunity()
  // - getMyCommunities()
  // - updateCommunity()
  // - deleteCommunity()
  // - etc.
}

