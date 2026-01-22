import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio para gestionar comunidades y entidades
/// Optimizado para plan gratuito de Firebase (minimiza reads/writes)
class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Inicializa las 4 entidades por defecto (ejecutar una sola vez)
  /// Retorna true si se crearon nuevas, false si ya existían todas
  /// Optimizado: solo hace writes si es necesario
  Future<bool> initializeEntityCommunities() async {
    try {
      final entities = [
        {'name': 'AMBIENTAL', 'description': 'Entidad Ambiental'},
        {'name': 'POLICIA', 'description': 'Policía Nacional'},
        {'name': 'BOMBEROS', 'description': 'Cuerpo de Bomberos'},
        {'name': 'TRANSITO', 'description': 'Tránsito y Transporte'},
      ];

      bool createdAny = false;

      for (final entity in entities) {
        // Verificar si ya existe (1 read por entidad)
        final existing = await _firestore
            .collection('communities')
            .where('name', isEqualTo: entity['name'])
            .where('is_entity', isEqualTo: true)
            .limit(1)
            .get();

        if (existing.docs.isEmpty) {
          // Crear la entidad (1 write)
          await _firestore.collection('communities').add({
            'name': entity['name'],
            'description': entity['description'],
            'is_entity': true,
            'created_by': null,
            'allow_forward_to_entities': false,
            'created_at': Timestamp.now(),
          });
          print('✅ Entidad creada: ${entity['name']}');
          createdAny = true;
        } else {
          print('ℹ️ Entidad ya existe: ${entity['name']}');
        }
      }

      return createdAny;
    } catch (e) {
      print('❌ Error inicializando entidades: $e');
      return false;
    }
  }

  /// Agrega usuario a todas las entidades cuando entra (idempotente)
  /// Se debe llamar cuando el usuario inicia sesión
  /// Optimizado: usa batch para minimizar writes
  Future<void> ensureUserInEntities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('⚠️ No hay usuario autenticado');
        return;
      }

      // Obtener todas las entidades (1 read)
      final entitiesSnapshot = await _firestore
          .collection('communities')
          .where('is_entity', isEqualTo: true)
          .get();

      if (entitiesSnapshot.docs.isEmpty) {
        print('⚠️ No hay entidades disponibles. Inicializando...');
        // Si no hay entidades, crearlas primero
        await initializeEntityCommunities();
        // Volver a obtener (1 read)
        final newSnapshot = await _firestore
            .collection('communities')
            .where('is_entity', isEqualTo: true)
            .get();
        
        if (newSnapshot.docs.isEmpty) {
          print('❌ No se pudieron crear las entidades');
          return;
        }
        
        // Continuar con el proceso
        await _addUserToEntities(userId, newSnapshot.docs);
        return;
      }

      await _addUserToEntities(userId, entitiesSnapshot.docs);
    } catch (e) {
      print('❌ Error agregando usuario a entidades: $e');
    }
  }

  /// Método privado para agregar usuario a entidades
  /// Usa batch para minimizar writes (plan gratuito)
  Future<void> _addUserToEntities(String userId, List<QueryDocumentSnapshot> entities) async {
    final batch = _firestore.batch();
    int added = 0;

    for (final entityDoc in entities) {
      final communityId = entityDoc.id;

      // Verificar si ya es miembro (1 read por entidad)
      final existingMember = await _firestore
          .collection('community_members')
          .where('user_id', isEqualTo: userId)
          .where('community_id', isEqualTo: communityId)
          .limit(1)
          .get();

      if (existingMember.docs.isEmpty) {
        // Agregar como miembro normal (role: 'member')
        // Los usuarios normales NO reciben alertas de entidades
        // Solo los miembros oficiales (role: 'official') reciben alertas
        final memberRef = _firestore.collection('community_members').doc();
        batch.set(memberRef, {
          'user_id': userId,
          'community_id': communityId,
          'joined_at': Timestamp.now(),
          'role': 'member', // Usuario normal - no recibe alertas de entidades
        });
        added++;
      }
    }

    if (added > 0) {
      // Ejecutar batch (1 write operation para todas las entidades)
      await batch.commit();
      print('✅ Usuario agregado a $added entidades');
    } else {
      print('ℹ️ Usuario ya estaba en todas las entidades');
    }
  }

  /// Obtiene las comunidades del usuario (incluye entidades y comunidades normales)
  /// Optimizado: usa queries eficientes para plan gratuito
  Future<List<Map<String, dynamic>>> getMyCommunities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      // Obtener todos los memberships del usuario (1 read)
      final membersSnapshot = await _firestore
          .collection('community_members')
          .where('user_id', isEqualTo: userId)
          .get();

      if (membersSnapshot.docs.isEmpty) return [];

      final communityIds = membersSnapshot.docs
          .map((doc) => doc.data()['community_id'] as String)
          .toList();

      if (communityIds.isEmpty) return [];

      // Firestore limita whereIn a 10 items, así que hacemos queries separadas si es necesario
      final List<Map<String, dynamic>> communities = [];

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
              'allow_forward_to_entities': data['allow_forward_to_entities'] ?? true,
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
      print('❌ Error obteniendo comunidades: $e');
      return [];
    }
  }

  /// Stream reactivo de comunidades del usuario
  /// Útil para actualizaciones en tiempo real
  Stream<List<Map<String, dynamic>>> getMyCommunitiesStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('community_members')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .asyncMap((membersSnapshot) async {
      if (membersSnapshot.docs.isEmpty) return <Map<String, dynamic>>[];

      final communityIds = membersSnapshot.docs
          .map((doc) => doc.data()['community_id'] as String)
          .toList();

      if (communityIds.isEmpty) return <Map<String, dynamic>>[];

      final List<Map<String, dynamic>> communities = [];

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
              'allow_forward_to_entities': data['allow_forward_to_entities'] ?? true,
            };
          }),
        );
      }

      communities.sort((a, b) {
        if (a['is_entity'] == b['is_entity']) {
          return (a['name'] as String).compareTo(b['name'] as String);
        }
        return (b['is_entity'] as bool) ? 1 : -1;
      });

      return communities;
    });
  }

  /// Obtiene los IDs de usuarios que deben recibir alertas de una comunidad
  /// Para entidades: solo miembros oficiales (role: 'official')
  /// Para comunidades normales: todos los miembros
  Future<List<String>> getAlertRecipients(String communityId) async {
    try {
      // Obtener información de la comunidad
      final communityDoc = await _firestore
          .collection('communities')
          .doc(communityId)
          .get();

      if (!communityDoc.exists) return [];

      final communityData = communityDoc.data();
      final isEntity = communityData?['is_entity'] ?? false;

      // Obtener miembros según el tipo de comunidad
      Query query = _firestore
          .collection('community_members')
          .where('community_id', isEqualTo: communityId);

      // Si es entidad, solo miembros oficiales
      if (isEntity) {
        query = query.where('role', isEqualTo: 'official');
      }
      // Si es comunidad normal, todos los miembros (sin filtro de role)

      final membersSnapshot = await query.get();

      return membersSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return '';
            return data['user_id'] as String? ?? '';
          })
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      print('❌ Error obteniendo destinatarios de alerta: $e');
      return [];
    }
  }

  /// Agrega un miembro oficial a una entidad
  /// Solo para uso administrativo - agregar policías, bomberos reales, etc.
  Future<bool> addOfficialMember(String userId, String communityId) async {
    try {
      // Verificar que la comunidad es una entidad
      final communityDoc = await _firestore
          .collection('communities')
          .doc(communityId)
          .get();

      if (!communityDoc.exists) {
        print('❌ Comunidad no existe');
        return false;
      }

      final isEntity = communityDoc.data()?['is_entity'] ?? false;
      if (!isEntity) {
        print('❌ Solo se pueden agregar miembros oficiales a entidades');
        return false;
      }

      // Verificar si ya existe
      final existing = await _firestore
          .collection('community_members')
          .where('user_id', isEqualTo: userId)
          .where('community_id', isEqualTo: communityId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Actualizar role a 'official'
        await existing.docs.first.reference.update({
          'role': 'official',
        });
        print('✅ Usuario actualizado a miembro oficial');
      } else {
        // Crear nuevo miembro oficial
        await _firestore.collection('community_members').add({
          'user_id': userId,
          'community_id': communityId,
          'joined_at': Timestamp.now(),
          'role': 'official',
        });
        print('✅ Miembro oficial agregado');
      }

      return true;
    } catch (e) {
      print('❌ Error agregando miembro oficial: $e');
      return false;
    }
  }
}

