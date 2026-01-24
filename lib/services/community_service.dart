import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'alert_repository.dart';

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
      
      // Invalidar cache de alertas (Iteración 2.5)
      AlertRepository().invalidateCommunityCache();
      
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

  /// Crea una nueva comunidad normal (no entidad)
  /// El creador se agrega automáticamente como 'admin'
  Future<String?> createCommunity({
    required String name,
    String? description,
    bool allowForwardToEntities = true,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('❌ No hay usuario autenticado');
        return null;
      }

      // Crear la comunidad
      final communityRef = await _firestore.collection('communities').add({
        'name': name,
        'description': description,
        'is_entity': false,
        'created_by': userId,
        'allow_forward_to_entities': allowForwardToEntities,
        'created_at': Timestamp.now(),
      });

      final communityId = communityRef.id;

      // Agregar al creador como admin
      await _firestore.collection('community_members').add({
        'user_id': userId,
        'community_id': communityId,
        'joined_at': Timestamp.now(),
        'role': 'admin', // El creador es admin
      });

      // Invalidar cache de alertas (Iteración 2.5)
      AlertRepository().invalidateCommunityCache();

      print('✅ Comunidad creada: $name (ID: $communityId)');
      return communityId;
    } catch (e) {
      print('❌ Error creando comunidad: $e');
      return null;
    }
  }

  /// Genera un link de invitación para una comunidad
  /// El token expira en 12 horas
  Future<String?> generateInviteLink(String communityId) async {
    try {
      // Verificar que la comunidad existe y no es entidad
      final communityDoc = await _firestore
          .collection('communities')
          .doc(communityId)
          .get();

      if (!communityDoc.exists) {
        print('❌ Comunidad no existe');
        return null;
      }

      final isEntity = communityDoc.data()?['is_entity'] ?? false;
      if (isEntity) {
        print('❌ No se pueden generar links de invitación para entidades');
        return null;
      }

      // Generar token único
      final token = _generateToken();

      // Crear invitación (expira en 12 horas)
      final expiresAt = DateTime.now().add(const Duration(hours: 12));
      await _firestore.collection('invites').doc(token).set({
        'community_id': communityId,
        'expires_at': Timestamp.fromDate(expiresAt),
      });

      // Retornar el link (formato: guardian.app/join/{token})
      return 'guardian.app/join/$token';
    } catch (e) {
      print('❌ Error generando link de invitación: $e');
      return null;
    }
  }

  /// Valida si un usuario existe en la app (por email)
  Future<bool> validateUserExists(String email) async {
    try {
      // Buscar usuario por email en Firestore users collection
      final usersSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();

      return usersSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error validando usuario: $e');
      return false;
    }
  }

  /// Obtiene información de una invitación sin unirse
  /// Útil para mostrar preview antes de confirmar
  Future<Map<String, dynamic>?> getInviteInfo(String token) async {
    try {
      final inviteDoc = await _firestore.collection('invites').doc(token).get();
      if (!inviteDoc.exists) {
        print('❌ Token de invitación no encontrado');
        return null;
      }

      final inviteData = inviteDoc.data();
      final communityId = inviteData?['community_id'] as String?;
      final expiresAt = (inviteData?['expires_at'] as Timestamp?)?.toDate();

      if (communityId == null || expiresAt == null) {
        print('❌ Datos de invitación inválidos');
        return null;
      }

      // Verificar expiración
      if (DateTime.now().isAfter(expiresAt)) {
        print('❌ Token de invitación expirado');
        return null;
      }

      return {
        'community_id': communityId,
        'expires_at': expiresAt,
        'is_valid': true,
      };
    } catch (e) {
      print('❌ Error obteniendo info de invitación: $e');
      return null;
    }
  }

  /// Une a un usuario a una comunidad mediante token de invitación
  /// Valida que el token no esté expirado y que el usuario exista
  Future<bool> joinCommunityByToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('❌ No hay usuario autenticado');
        return false;
      }

      // Obtener la invitación
      final inviteDoc = await _firestore.collection('invites').doc(token).get();
      if (!inviteDoc.exists) {
        print('❌ Token de invitación no válido');
        return false;
      }

      final inviteData = inviteDoc.data();
      final communityId = inviteData?['community_id'] as String?;
      final expiresAt = (inviteData?['expires_at'] as Timestamp?)?.toDate();

      if (communityId == null || expiresAt == null) {
        print('❌ Datos de invitación inválidos');
        return false;
      }

      // Verificar expiración
      if (DateTime.now().isAfter(expiresAt)) {
        print('❌ Token de invitación expirado');
        return false;
      }

      // Verificar si ya es miembro
      final existingMember = await _firestore
          .collection('community_members')
          .where('user_id', isEqualTo: userId)
          .where('community_id', isEqualTo: communityId)
          .limit(1)
          .get();

      if (existingMember.docs.isNotEmpty) {
        print('ℹ️ Usuario ya es miembro de esta comunidad');
        return true; // Ya es miembro, consideramos éxito
      }

      // Agregar como miembro normal
      await _firestore.collection('community_members').add({
        'user_id': userId,
        'community_id': communityId,
        'joined_at': Timestamp.now(),
        'role': 'member', // Nuevo miembro es 'member'
      });

      // Invalidar cache de alertas (Iteración 2.5)
      AlertRepository().invalidateCommunityCache();

      print('✅ Usuario agregado a la comunidad');
      return true;
    } catch (e) {
      print('❌ Error uniéndose a comunidad: $e');
      return false;
    }
  }

  /// Obtiene el rol del usuario actual en una comunidad
  /// Retorna 'admin', 'member', 'official' o null si no es miembro
  Future<String?> getUserRole(String communityId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final memberSnapshot = await _firestore
          .collection('community_members')
          .where('user_id', isEqualTo: userId)
          .where('community_id', isEqualTo: communityId)
          .limit(1)
          .get();

      if (memberSnapshot.docs.isEmpty) return null;

      final data = memberSnapshot.docs.first.data();
      return data['role'] as String? ?? 'member';
    } catch (e) {
      print('❌ Error obteniendo rol de usuario: $e');
      return null;
    }
  }

  /// Abandona una comunidad (solo para comunidades normales, no entidades)
  Future<bool> leaveCommunity(String communityId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('❌ No hay usuario autenticado');
        return false;
      }

      // Verificar que la comunidad existe y no es entidad
      final communityDoc = await _firestore
          .collection('communities')
          .doc(communityId)
          .get();

      if (!communityDoc.exists) {
        print('❌ Comunidad no existe');
        return false;
      }

      final isEntity = communityDoc.data()?['is_entity'] ?? false;
      if (isEntity) {
        print('⚠️ No se puede abandonar una entidad oficial');
        return false;
      }

      // Buscar y eliminar el membership
      final memberSnapshot = await _firestore
          .collection('community_members')
          .where('user_id', isEqualTo: userId)
          .where('community_id', isEqualTo: communityId)
          .limit(1)
          .get();

      if (memberSnapshot.docs.isEmpty) {
        print('ℹ️ Usuario no es miembro de esta comunidad');
        return false;
      }

      // Validar que NO sea admin (el creador no puede abandonar su propia comunidad)
      final memberData = memberSnapshot.docs.first.data();
      final role = memberData['role'] as String? ?? 'member';
      if (role == 'admin') {
        print('⚠️ El administrador (creador) no puede abandonar su propia comunidad');
        return false;
      }

      // Eliminar el membership
      await memberSnapshot.docs.first.reference.delete();
      
      // Invalidar cache de alertas (Iteración 2.5)
      AlertRepository().invalidateCommunityCache();
      
      print('✅ Usuario abandonó la comunidad');
      return true;
    } catch (e) {
      print('❌ Error abandonando comunidad: $e');
      return false;
    }
  }

  /// Elimina una comunidad (solo el creador puede eliminar)
  /// También elimina todos los miembros y invitaciones asociadas
  Future<bool> deleteCommunity(String communityId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('❌ No hay usuario autenticado');
        return false;
      }

      // Obtener la comunidad
      final communityDoc = await _firestore
          .collection('communities')
          .doc(communityId)
          .get();

      if (!communityDoc.exists) {
        print('❌ Comunidad no existe');
        return false;
      }

      final communityData = communityDoc.data();
      final isEntity = communityData?['is_entity'] ?? false;
      final createdBy = communityData?['created_by'] as String?;

      // No se pueden eliminar entidades
      if (isEntity) {
        print('⚠️ No se pueden eliminar entidades oficiales');
        return false;
      }

      // Solo el creador puede eliminar
      if (createdBy != userId) {
        print('⚠️ Solo el creador puede eliminar la comunidad');
        return false;
      }

      // Usar batch para eliminar todo de forma atómica
      final batch = _firestore.batch();

      // 1. Eliminar todos los miembros de la comunidad
      final membersSnapshot = await _firestore
          .collection('community_members')
          .where('community_id', isEqualTo: communityId)
          .get();

      for (final doc in membersSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 2. Eliminar todas las invitaciones de la comunidad
      final invitesSnapshot = await _firestore
          .collection('invites')
          .where('community_id', isEqualTo: communityId)
          .get();

      for (final doc in invitesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 3. Eliminar la comunidad
      batch.delete(communityDoc.reference);

      // Ejecutar batch
      await batch.commit();

      // Invalidar cache de alertas
      AlertRepository().invalidateCommunityCache();

      print('✅ Comunidad eliminada: $communityId');
      return true;
    } catch (e) {
      print('❌ Error eliminando comunidad: $e');
      return false;
    }
  }

  /// Verifica si el usuario actual es el creador de una comunidad
  Future<bool> isCreator(String communityId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final communityDoc = await _firestore
          .collection('communities')
          .doc(communityId)
          .get();

      if (!communityDoc.exists) return false;

      final createdBy = communityDoc.data()?['created_by'] as String?;
      return createdBy == userId;
    } catch (e) {
      print('❌ Error verificando creador: $e');
      return false;
    }
  }

  /// Actualiza una comunidad (solo el creador puede actualizar)
  Future<bool> updateCommunity(String communityId, {
    String? name,
    String? description,
    bool? allowForwardToEntities,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('❌ No hay usuario autenticado');
        return false;
      }

      // Verificar que es el creador
      final isOwner = await isCreator(communityId);
      if (!isOwner) {
        print('⚠️ Solo el creador puede actualizar la comunidad');
        return false;
      }

      // Construir datos a actualizar
      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (allowForwardToEntities != null) {
        updateData['allow_forward_to_entities'] = allowForwardToEntities;
      }

      if (updateData.isEmpty) {
        print('ℹ️ No hay datos para actualizar');
        return true;
      }

      await _firestore
          .collection('communities')
          .doc(communityId)
          .update(updateData);

      print('✅ Comunidad actualizada');
      return true;
    } catch (e) {
      print('❌ Error actualizando comunidad: $e');
      return false;
    }
  }

  /// Genera un token único y seguro para invitaciones (32 caracteres alfanuméricos)
  /// Usa múltiples fuentes de aleatoriedad para garantizar unicidad y seguridad
  String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure(); // Usa Random.secure() para criptográficamente seguro
    final buffer = StringBuffer();
    
    // Combinar múltiples fuentes de aleatoriedad:
    // 1. Random.secure() (criptográficamente seguro)
    // 2. Timestamp actual (unicidad temporal)
    // 3. Microsegundos (granularidad adicional)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final microseconds = DateTime.now().microsecondsSinceEpoch;
    final randomSeed = random.nextInt(1000000);
    
    // Generar 32 caracteres usando múltiples fuentes
    for (int i = 0; i < 32; i++) {
      // Combinar todas las fuentes de aleatoriedad
      final combined = (timestamp + microseconds + randomSeed + i) % chars.length;
      final randomIndex = random.nextInt(chars.length);
      // XOR de ambos índices para mayor aleatoriedad
      final finalIndex = (combined ^ randomIndex) % chars.length;
      buffer.write(chars[finalIndex]);
    }
    
    return buffer.toString();
  }
}

