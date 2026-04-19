import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../core/entity_definitions.dart';
import '../core/mixins/community_fetch_mixin.dart';
import 'alert_repository.dart';
import '../models/member_report_model.dart';

/// Result returned by operations that join a community.
class JoinResult {
  final bool success;
  final bool alreadyMember;
  final String? role;
  final String? message;

  JoinResult({
    required this.success,
    this.alreadyMember = false,
    this.role,
    this.message,
  });
}

/// Service responsible for all community-related business logic.
///
/// Optimised for Firebase Spark (free) plan: minimises read/write operations
/// through batching and selective queries.
class CommunityService with CommunityFetchMixin {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  @override
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Entity Bootstrapping ────────────────────────────────────────────────

  /// Seeds the four built-in entity communities if they do not yet exist.
  ///
  /// Safe to call multiple times (idempotent). Returns [true] if any new
  /// entities were created.
  Future<bool> initializeEntityCommunities() async {
    try {
      bool createdAny = false;

      for (final entity in EntityDefinitions.defaultEntities) {
        final existing = await firestore
            .collection(FirestoreCollections.communities)
            .where(CommunityFields.name, isEqualTo: entity[CommunityFields.name])
            .where(CommunityFields.isEntity, isEqualTo: true)
            .limit(1)
            .get();

        if (existing.docs.isEmpty) {
          await firestore
              .collection(FirestoreCollections.communities)
              .add(EntityDefinitions.toFirestore(entity));
          AppLogger.d('Entity created: ${entity[CommunityFields.name]}');
          createdAny = true;
        } else {
          AppLogger.d('Entity already exists: ${entity[CommunityFields.name]}');
        }
      }

      return createdAny;
    } catch (e) {
      AppLogger.e('initializeEntityCommunities', e);
      return false;
    }
  }

  /// Ensures the current user is a member of every entity community.
  ///
  /// Called after login/registration to provide automatic entity membership.
  /// Uses a Firestore batch to minimise write operations.
  Future<void> ensureUserInEntities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        AppLogger.w('ensureUserInEntities: no authenticated user');
        return;
      }

      var entitiesSnap = await firestore
          .collection(FirestoreCollections.communities)
          .where(CommunityFields.isEntity, isEqualTo: true)
          .get();

      if (entitiesSnap.docs.isEmpty) {
        AppLogger.w('No entities found — seeding now');
        await initializeEntityCommunities();
        entitiesSnap = await firestore
            .collection(FirestoreCollections.communities)
            .where(CommunityFields.isEntity, isEqualTo: true)
            .get();

        if (entitiesSnap.docs.isEmpty) {
          AppLogger.e('Could not seed entities');
          return;
        }
      }

      await _addUserToEntities(userId, entitiesSnap.docs);
    } catch (e) {
      AppLogger.e('ensureUserInEntities', e);
    }
  }

  Future<void> _addUserToEntities(
    String userId,
    List<QueryDocumentSnapshot> entities,
  ) async {
    final batch = firestore.batch();
    int added = 0;

    for (final entityDoc in entities) {
      final communityId = entityDoc.id;

      final existingMember = await firestore
          .collection(FirestoreCollections.communityMembers)
          .where(MemberFields.userId, isEqualTo: userId)
          .where(MemberFields.communityId, isEqualTo: communityId)
          .limit(1)
          .get();

      if (existingMember.docs.isEmpty) {
        final ref = firestore.collection(FirestoreCollections.communityMembers).doc();
        batch.set(ref, {
          MemberFields.userId: userId,
          MemberFields.communityId: communityId,
          MemberFields.joinedAt: Timestamp.now(),
          MemberFields.role: MemberFields.roleMember,
        });
        added++;
      }
    }

    if (added > 0) {
      await batch.commit();
      AlertRepository().invalidateCommunityCache();
      AppLogger.d('User added to $added entities');
    } else {
      AppLogger.d('User already belongs to all entities');
    }
  }

  // ─── Community Queries ───────────────────────────────────────────────────

  /// Returns all communities the current user belongs to.
  Future<List<Map<String, dynamic>>> getMyCommunities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      return fetchUserCommunities(userId);
    } catch (e) {
      AppLogger.e('getMyCommunities', e);
      return [];
    }
  }

  /// Reactive stream of the current user's communities.
  Stream<List<Map<String, dynamic>>> getMyCommunitiesStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.userId, isEqualTo: userId)
        .snapshots()
        .asyncMap((_) => getMyCommunities());
  }

  // ─── Alert Recipients ────────────────────────────────────────────────────

  /// Returns the user IDs that should receive alerts for [communityId].
  ///
  /// Entities → only `official` members.
  /// Normal communities → all members.
  Future<List<String>> getAlertRecipients(String communityId) async {
    try {
      final communityDoc = await firestore
          .collection(FirestoreCollections.communities)
          .doc(communityId)
          .get();

      if (!communityDoc.exists) return [];

      final isEntity = communityDoc.data()?[CommunityFields.isEntity] ?? false;

      Query query = firestore
          .collection(FirestoreCollections.communityMembers)
          .where(MemberFields.communityId, isEqualTo: communityId);

      if (isEntity) {
        query = query.where(MemberFields.role, isEqualTo: MemberFields.roleOfficial);
      }

      final snap = await query.get();

      return snap.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data?[MemberFields.userId] as String? ?? '';
          })
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      AppLogger.e('getAlertRecipients', e);
      return [];
    }
  }

  // ─── Official Members ────────────────────────────────────────────────────

  /// Adds or promotes [userId] as an `official` member of [communityId].
  Future<bool> addOfficialMember(String userId, String communityId) async {
    try {
      final communityDoc = await firestore
          .collection(FirestoreCollections.communities)
          .doc(communityId)
          .get();

      if (!communityDoc.exists) {
        AppLogger.e('addOfficialMember: community not found');
        return false;
      }

      if (!(communityDoc.data()?[CommunityFields.isEntity] ?? false)) {
        AppLogger.e('addOfficialMember: target is not an entity');
        return false;
      }

      final existing = await firestore
          .collection(FirestoreCollections.communityMembers)
          .where(MemberFields.userId, isEqualTo: userId)
          .where(MemberFields.communityId, isEqualTo: communityId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update({MemberFields.role: MemberFields.roleOfficial});
        AppLogger.d('Updated user to official member');
      } else {
        await firestore.collection(FirestoreCollections.communityMembers).add({
          MemberFields.userId: userId,
          MemberFields.communityId: communityId,
          MemberFields.joinedAt: Timestamp.now(),
          MemberFields.role: MemberFields.roleOfficial,
        });
        AppLogger.d('Official member added');
      }

      return true;
    } catch (e) {
      AppLogger.e('addOfficialMember', e);
      return false;
    }
  }

  // ─── Create / Update / Delete Community ─────────────────────────────────

  /// Creates a new (non-entity) community. The creator is automatically added
  /// as `admin`.
  Future<String?> createCommunity({
    required String name,
    String? description,
    bool allowForwardToEntities = true,
    int? iconCodePoint,
    String? iconColor,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        AppLogger.e('createCommunity: no authenticated user');
        return null;
      }

      final data = <String, dynamic>{
        CommunityFields.name: name,
        CommunityFields.description: description,
        CommunityFields.isEntity: false,
        CommunityFields.createdBy: userId,
        CommunityFields.allowForwardToEntities: allowForwardToEntities,
        CommunityFields.createdAt: Timestamp.now(),
      };
      if (iconCodePoint != null) data[CommunityFields.iconCodePoint] = iconCodePoint;
      if (iconColor != null) data[CommunityFields.iconColor] = iconColor;

      final ref = await firestore.collection(FirestoreCollections.communities).add(data);

      await firestore.collection(FirestoreCollections.communityMembers).add({
        MemberFields.userId: userId,
        MemberFields.communityId: ref.id,
        MemberFields.joinedAt: Timestamp.now(),
        MemberFields.role: MemberFields.roleAdmin,
      });

      AlertRepository().invalidateCommunityCache();
      AppLogger.d('Community created: $name (${ref.id})');
      return ref.id;
    } catch (e) {
      AppLogger.e('createCommunity', e);
      return null;
    }
  }

  /// Generates a time-limited invite link for [communityId].
  Future<String?> generateInviteLink(String communityId) async {
    try {
      final communityDoc = await firestore
          .collection(FirestoreCollections.communities)
          .doc(communityId)
          .get();

      if (!communityDoc.exists) {
        AppLogger.e('generateInviteLink: community not found');
        return null;
      }

      if (communityDoc.data()?[CommunityFields.isEntity] ?? false) {
        AppLogger.e('generateInviteLink: entities cannot have invite links');
        return null;
      }

      final token = _generateToken();
      final expiresAt = DateTime.now().add(AppDurations.inviteExpiry);

      await firestore.collection(FirestoreCollections.invites).doc(token).set({
        InviteFields.communityId: communityId,
        InviteFields.expiresAt: Timestamp.fromDate(expiresAt),
      });

      return '${AppUrls.inviteLinkBase}$token';
    } catch (e) {
      AppLogger.e('generateInviteLink', e);
      return null;
    }
  }

  /// Verifies that a user with [email] exists in the `users` collection.
  Future<bool> validateUserExists(String email) async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.users)
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      AppLogger.e('validateUserExists', e);
      return false;
    }
  }

  /// Searches users by email (exact) or name (substring, client-side).
  ///
  /// Excludes the current user and existing members of [excludeCommunityId].
  Future<List<Map<String, dynamic>>> searchUsers(
    String query, {
    String? excludeCommunityId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      final trimmed = query.trim().toLowerCase();
      if (trimmed.isEmpty || trimmed.length < 2) return [];

      final results = <Map<String, dynamic>>[];
      final addedIds = <String>{};

      Set<String> existingMemberIds = {};
      if (excludeCommunityId != null) {
        final membersSnap = await firestore
            .collection(FirestoreCollections.communityMembers)
            .where(MemberFields.communityId, isEqualTo: excludeCommunityId)
            .get();
        existingMemberIds = membersSnap.docs
            .map((d) => d.data()[MemberFields.userId] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
      }

      // Exact email match.
      final emailSnap = await firestore
          .collection(FirestoreCollections.users)
          .where('email', isEqualTo: trimmed)
          .limit(5)
          .get();

      for (final doc in emailSnap.docs) {
        final uid = doc.id;
        if (uid == userId || existingMemberIds.contains(uid) || addedIds.contains(uid)) continue;
        addedIds.add(uid);
        final data = doc.data();
        results.add(_userMapFrom(uid, data));
      }

      // Name/email substring — client-side filter on a bounded batch.
      if (results.length < 10) {
        final nameSnap = await firestore
            .collection(FirestoreCollections.users)
            .limit(100)
            .get();

        for (final doc in nameSnap.docs) {
          if (results.length >= 10) break;
          final uid = doc.id;
          if (uid == userId || existingMemberIds.contains(uid) || addedIds.contains(uid)) continue;

          final data = doc.data();
          final name = (_displayName(data)).toLowerCase();
          final email = (data['email'] as String? ?? '').toLowerCase();

          if (name.contains(trimmed) || email.contains(trimmed)) {
            addedIds.add(uid);
            results.add(_userMapFrom(uid, data));
          }
        }
      }

      return results;
    } catch (e) {
      AppLogger.e('searchUsers', e);
      return [];
    }
  }

  /// In-app welcome pipeline: Firestore doc consumed by clients (snackbar / future push).
  Future<void> emitMemberAddedWelcomeSignal({
    required String targetUserId,
    required String communityId,
  }) async {
    try {
      final commSnap = await firestore
          .collection(FirestoreCollections.communities)
          .doc(communityId)
          .get();
      final commName =
          commSnap.data()?[CommunityFields.name] as String? ?? '';
      await firestore.collection(FirestoreCollections.memberAddedSignals).add({
        MemberAddedSignalFields.targetUserId: targetUserId,
        MemberAddedSignalFields.communityId: communityId,
        MemberAddedSignalFields.communityName: commName,
        MemberAddedSignalFields.createdAt: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.e('emitMemberAddedWelcomeSignal', e);
    }
  }

  /// Adds [targetUserId] directly to [communityId] (admin only).
  Future<JoinResult> addMemberDirectly(String communityId, String targetUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return JoinResult(success: false, message: 'No hay usuario autenticado');
      }

      if (await getUserRole(communityId) != MemberFields.roleAdmin) {
        return JoinResult(success: false, message: 'Solo administradores pueden agregar miembros');
      }

      final targetDoc = await firestore
          .collection(FirestoreCollections.users)
          .doc(targetUserId)
          .get();
      if (!targetDoc.exists) {
        return JoinResult(success: false, message: 'Usuario no encontrado');
      }

      final existing = await firestore
          .collection(FirestoreCollections.communityMembers)
          .where(MemberFields.userId, isEqualTo: targetUserId)
          .where(MemberFields.communityId, isEqualTo: communityId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final role = existing.docs.first.data()[MemberFields.role] as String? ?? MemberFields.roleMember;
        return JoinResult(
          success: true,
          alreadyMember: true,
          role: role,
          message: 'Este usuario ya es miembro de la comunidad',
        );
      }

      await firestore.collection(FirestoreCollections.communityMembers).add({
        MemberFields.userId: targetUserId,
        MemberFields.communityId: communityId,
        MemberFields.joinedAt: Timestamp.now(),
        MemberFields.role: MemberFields.roleMember,
      });

      final targetName = _displayName(targetDoc.data() ?? {});
      AppLogger.d('User $targetName added to community');

      await emitMemberAddedWelcomeSignal(
        targetUserId: targetUserId,
        communityId: communityId,
      );

      return JoinResult(
        success: true,
        role: MemberFields.roleMember,
        message: '$targetName ha sido agregado a la comunidad',
      );
    } catch (e) {
      AppLogger.e('addMemberDirectly', e);
      return JoinResult(success: false, message: 'Error al agregar miembro');
    }
  }

  // ─── Invite Handling ─────────────────────────────────────────────────────

  /// Returns invite metadata without consuming the token.
  Future<Map<String, dynamic>?> getInviteInfo(String token) async {
    try {
      final inviteDoc = await firestore
          .collection(FirestoreCollections.invites)
          .doc(token)
          .get();

      if (!inviteDoc.exists) {
        AppLogger.e('Invite token not found');
        return null;
      }

      final data = inviteDoc.data();
      final communityId = data?[InviteFields.communityId] as String?;
      final expiresAt = (data?[InviteFields.expiresAt] as Timestamp?)?.toDate();

      if (communityId == null || expiresAt == null) {
        AppLogger.e('Invalid invite data');
        return null;
      }

      if (DateTime.now().isAfter(expiresAt)) {
        AppLogger.w('Invite token expired');
        return null;
      }

      return {
        InviteFields.communityId: communityId,
        InviteFields.expiresAt: expiresAt,
        'is_valid': true,
      };
    } catch (e) {
      AppLogger.e('getInviteInfo', e);
      return null;
    }
  }

  /// Joins the current user to the community identified by [token].
  Future<JoinResult> joinCommunityByToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return JoinResult(success: false, message: 'No hay usuario autenticado');
      }

      final inviteDoc = await firestore
          .collection(FirestoreCollections.invites)
          .doc(token)
          .get();
      if (!inviteDoc.exists) {
        return JoinResult(success: false, message: 'Token de invitación no válido');
      }

      final data = inviteDoc.data();
      final communityId = data?[InviteFields.communityId] as String?;
      final expiresAt = (data?[InviteFields.expiresAt] as Timestamp?)?.toDate();

      if (communityId == null || expiresAt == null) {
        return JoinResult(success: false, message: 'Datos de invitación inválidos');
      }

      if (DateTime.now().isAfter(expiresAt)) {
        return JoinResult(success: false, message: 'El link de invitación ha expirado');
      }

      final existing = await firestore
          .collection(FirestoreCollections.communityMembers)
          .where(MemberFields.userId, isEqualTo: userId)
          .where(MemberFields.communityId, isEqualTo: communityId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final role = existing.docs.first.data()[MemberFields.role] as String? ?? MemberFields.roleMember;
        return JoinResult(
          success: true,
          alreadyMember: true,
          role: role,
          message: role == MemberFields.roleAdmin
              ? 'Ya eres administrador de esta comunidad'
              : 'Ya eres miembro de esta comunidad',
        );
      }

      await firestore.collection(FirestoreCollections.communityMembers).add({
        MemberFields.userId: userId,
        MemberFields.communityId: communityId,
        MemberFields.joinedAt: Timestamp.now(),
        MemberFields.role: MemberFields.roleMember,
      });

      AlertRepository().invalidateCommunityCache();
      AppLogger.d('User joined community via token');

      await emitMemberAddedWelcomeSignal(
        targetUserId: userId,
        communityId: communityId,
      );

      return JoinResult(
        success: true,
        alreadyMember: false,
        role: MemberFields.roleMember,
        message: 'Te has unido exitosamente a la comunidad',
      );
    } catch (e) {
      AppLogger.e('joinCommunityByToken', e);
      return JoinResult(success: false, message: 'Error al unirse a la comunidad');
    }
  }

  // ─── Role Queries ────────────────────────────────────────────────────────

  /// Returns the current user's role in [communityId], or `null` if not a member.
  Future<String?> getUserRole(String communityId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final snap = await firestore
          .collection(FirestoreCollections.communityMembers)
          .where(MemberFields.userId, isEqualTo: userId)
          .where(MemberFields.communityId, isEqualTo: communityId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data()[MemberFields.role] as String? ?? MemberFields.roleMember;
    } catch (e) {
      AppLogger.e('getUserRole', e);
      return null;
    }
  }

  // ─── Leave / Delete ──────────────────────────────────────────────────────

  /// Removes the current user from [communityId].
  ///
  /// Throws if the community is an entity, if the user is not a member, or if
  /// they are the sole admin.
  Future<bool> leaveCommunity(String communityId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Usuario no autenticado');

    final communityDoc = await firestore
        .collection(FirestoreCollections.communities)
        .doc(communityId)
        .get();

    if (!communityDoc.exists) throw Exception('La comunidad no existe');
    if (communityDoc.data()?[CommunityFields.isEntity] ?? false) {
      throw Exception('No se puede abandonar una entidad oficial');
    }

    final memberSnap = await firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.userId, isEqualTo: userId)
        .where(MemberFields.communityId, isEqualTo: communityId)
        .limit(1)
        .get();

    if (memberSnap.docs.isEmpty) throw Exception('No eres miembro de esta comunidad');

    final role = memberSnap.docs.first.data()[MemberFields.role] as String? ?? MemberFields.roleMember;
    if (role == MemberFields.roleAdmin) {
      final adminsSnap = await firestore
          .collection(FirestoreCollections.communityMembers)
          .where(MemberFields.communityId, isEqualTo: communityId)
          .where(MemberFields.role, isEqualTo: MemberFields.roleAdmin)
          .get();

      if (adminsSnap.docs.length <= 1) {
        throw Exception('Eres el único administrador. Promueve a otro miembro antes de salir.');
      }
    }

    await memberSnap.docs.first.reference.delete();
    AlertRepository().invalidateCommunityCache();
    return true;
  }

  /// Deletes [communityId] along with all its members and invites.
  ///
  /// Only the community creator may perform this action.
  Future<bool> deleteCommunity(String communityId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        AppLogger.e('deleteCommunity: no authenticated user');
        return false;
      }

      final communityDoc = await firestore
          .collection(FirestoreCollections.communities)
          .doc(communityId)
          .get();

      if (!communityDoc.exists) {
        AppLogger.e('deleteCommunity: community not found');
        return false;
      }

      final data = communityDoc.data()!;
      if (data[CommunityFields.isEntity] ?? false) {
        AppLogger.w('deleteCommunity: cannot delete entity communities');
        return false;
      }
      if ((data[CommunityFields.createdBy] as String?) != userId) {
        AppLogger.w('deleteCommunity: only the creator can delete the community');
        return false;
      }

      final batch = firestore.batch();

      final membersSnap = await firestore
          .collection(FirestoreCollections.communityMembers)
          .where(MemberFields.communityId, isEqualTo: communityId)
          .get();
      for (final doc in membersSnap.docs) {
        batch.delete(doc.reference);
      }

      final invitesSnap = await firestore
          .collection(FirestoreCollections.invites)
          .where(InviteFields.communityId, isEqualTo: communityId)
          .get();
      for (final doc in invitesSnap.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(communityDoc.reference);
      await batch.commit();

      AlertRepository().invalidateCommunityCache();
      AppLogger.d('Community deleted: $communityId');
      return true;
    } catch (e) {
      AppLogger.e('deleteCommunity', e);
      return false;
    }
  }

  /// Returns `true` if the current user is the creator of [communityId].
  Future<bool> isCreator(String communityId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final doc = await firestore
          .collection(FirestoreCollections.communities)
          .doc(communityId)
          .get();

      if (!doc.exists) return false;
      return (doc.data()?[CommunityFields.createdBy] as String?) == userId;
    } catch (e) {
      AppLogger.e('isCreator', e);
      return false;
    }
  }

  /// Updates mutable fields of [communityId]. Only the creator may do this.
  Future<bool> updateCommunity(
    String communityId, {
    String? name,
    String? description,
    bool? allowForwardToEntities,
    int? iconCodePoint,
    String? iconColor,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        AppLogger.e('updateCommunity: no authenticated user');
        return false;
      }

      if (!await isCreator(communityId)) {
        AppLogger.w('updateCommunity: only the creator can update');
        return false;
      }

      final updateData = <String, dynamic>{};
      if (name != null) updateData[CommunityFields.name] = name;
      if (description != null) updateData[CommunityFields.description] = description;
      if (allowForwardToEntities != null) {
        updateData[CommunityFields.allowForwardToEntities] = allowForwardToEntities;
      }
      if (iconCodePoint != null) updateData[CommunityFields.iconCodePoint] = iconCodePoint;
      if (iconColor != null) updateData[CommunityFields.iconColor] = iconColor;

      if (updateData.isEmpty) return true;

      await firestore
          .collection(FirestoreCollections.communities)
          .doc(communityId)
          .update(updateData);

      AppLogger.d('Community updated: $communityId');
      return true;
    } catch (e) {
      AppLogger.e('updateCommunity', e);
      return false;
    }
  }

  // ─── Member Management ───────────────────────────────────────────────────

  /// Returns the list of members of [communityId] enriched with user data.
  Future<List<Map<String, dynamic>>> getCommunityMembers(String communityId) async {
    try {
      final membersSnap = await firestore
          .collection(FirestoreCollections.communityMembers)
          .where(MemberFields.communityId, isEqualTo: communityId)
          .get();

      if (membersSnap.docs.isEmpty) return [];

      final members = <Map<String, dynamic>>[];

      for (final memberDoc in membersSnap.docs) {
        final memberData = memberDoc.data();
        final userId = memberData[MemberFields.userId] as String? ?? '';
        if (userId.isEmpty) continue;

        String? userName;
        String? userEmail;

        try {
          final userDoc = await firestore
              .collection(FirestoreCollections.users)
              .doc(userId)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data()!;
            userName = _displayName(data);
            userEmail = data['email'] as String?;
          }
        } catch (_) {}

        if (userName == null && userId == _auth.currentUser?.uid) {
          userName = _auth.currentUser?.displayName;
          userEmail ??= _auth.currentUser?.email;
        }

        members.add({
          'member_id': memberDoc.id,
          MemberFields.userId: userId,
          'user_name': userName ?? userEmail?.split('@')[0] ?? 'Usuario',
          'user_email': userEmail ?? '',
          MemberFields.role: memberData[MemberFields.role] as String? ?? MemberFields.roleMember,
          'joined_at': (memberData[MemberFields.joinedAt] as Timestamp?)?.toDate() ?? DateTime.now(),
        });
      }

      const roleOrder = {
        MemberFields.roleAdmin: 0,
        MemberFields.roleOfficial: 1,
        MemberFields.roleMember: 2,
      };

      members.sort((a, b) {
        final aOrd = roleOrder[a[MemberFields.role]] ?? 3;
        final bOrd = roleOrder[b[MemberFields.role]] ?? 3;
        if (aOrd != bOrd) return aOrd.compareTo(bOrd);
        return (a['user_name'] as String).compareTo(b['user_name'] as String);
      });

      return members;
    } catch (e) {
      AppLogger.e('getCommunityMembers', e);
      return [];
    }
  }

  /// Removes [targetUserId] from [communityId]. Admins only; cannot remove
  /// other admins or self.
  Future<bool> removeMember(String communityId, String targetUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      if (await getUserRole(communityId) != MemberFields.roleAdmin) {
        AppLogger.w('removeMember: caller is not admin');
        return false;
      }
      if (targetUserId == userId) {
        AppLogger.w('removeMember: cannot remove self');
        return false;
      }

      final targetSnap = await firestore
          .collection(FirestoreCollections.communityMembers)
          .where(MemberFields.userId, isEqualTo: targetUserId)
          .where(MemberFields.communityId, isEqualTo: communityId)
          .limit(1)
          .get();

      if (targetSnap.docs.isEmpty) {
        AppLogger.w('removeMember: target is not a member');
        return false;
      }

      final targetRole =
          targetSnap.docs.first.data()[MemberFields.role] as String? ?? MemberFields.roleMember;
      if (targetRole == MemberFields.roleAdmin) {
        AppLogger.w('removeMember: cannot remove another admin');
        return false;
      }

      await targetSnap.docs.first.reference.delete();
      AppLogger.d('Member removed from $communityId');
      return true;
    } catch (e) {
      AppLogger.e('removeMember', e);
      return false;
    }
  }

  /// Promotes [targetUserId] to admin in [communityId]. Admins only.
  Future<bool> promoteToAdmin(String communityId, String targetUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      if (await getUserRole(communityId) != MemberFields.roleAdmin) {
        AppLogger.w('promoteToAdmin: caller is not admin');
        return false;
      }

      final targetSnap = await firestore
          .collection(FirestoreCollections.communityMembers)
          .where(MemberFields.userId, isEqualTo: targetUserId)
          .where(MemberFields.communityId, isEqualTo: communityId)
          .limit(1)
          .get();

      if (targetSnap.docs.isEmpty) {
        AppLogger.w('promoteToAdmin: target is not a member');
        return false;
      }

      final targetRole =
          targetSnap.docs.first.data()[MemberFields.role] as String? ?? MemberFields.roleMember;
      if (targetRole == MemberFields.roleAdmin) {
        AppLogger.d('promoteToAdmin: user is already admin');
        return true;
      }

      await targetSnap.docs.first.reference.update({MemberFields.role: MemberFields.roleAdmin});
      AppLogger.d('Member promoted to admin');
      return true;
    } catch (e) {
      AppLogger.e('promoteToAdmin', e);
      return false;
    }
  }

  // ─── Member Reports ──────────────────────────────────────────────────────

  /// Creates a report against [reportedUserId] in [communityId].
  Future<bool> reportMember({
    required String communityId,
    required String reportedUserId,
    required String reason,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      if (reportedUserId == userId) {
        AppLogger.w('reportMember: cannot report self');
        return false;
      }
      if (await getUserRole(communityId) == null) {
        AppLogger.w('reportMember: caller is not a member');
        return false;
      }

      final report = MemberReportModel(
        communityId: communityId,
        reportedUserId: reportedUserId,
        reportedByUserId: userId,
        reason: reason,
        createdAt: DateTime.now(),
        status: ReportFields.statusPending,
      );

      await firestore
          .collection(FirestoreCollections.memberReports)
          .add(report.toFirestore());
      AppLogger.d('Member report created');
      return true;
    } catch (e) {
      AppLogger.e('reportMember', e);
      return false;
    }
  }

  /// Returns pending member reports for [communityId]. Admins only.
  Future<List<Map<String, dynamic>>> getReportsForCommunity(String communityId) async {
    try {
      if (await getUserRole(communityId) != MemberFields.roleAdmin) {
        AppLogger.w('getReportsForCommunity: caller is not admin');
        return [];
      }

      final reportsSnap = await firestore
          .collection(FirestoreCollections.memberReports)
          .where(ReportFields.communityId, isEqualTo: communityId)
          .where(ReportFields.status, isEqualTo: ReportFields.statusPending)
          .orderBy(ReportFields.createdAt, descending: true)
          .get();

      final reports = <Map<String, dynamic>>[];

      for (final reportDoc in reportsSnap.docs) {
        final reportData = reportDoc.data();
        final reportedId = reportData[ReportFields.reportedUserId] as String? ?? '';
        final reportedById = reportData[ReportFields.reportedByUserId] as String? ?? '';

        final reportedName = await _getDisplayNameForUser(reportedId);
        final reportedByName = await _getDisplayNameForUser(reportedById);

        reports.add({
          'report_id': reportDoc.id,
          ReportFields.reportedUserId: reportedId,
          'reported_user_name': reportedName,
          ReportFields.reportedByUserId: reportedById,
          'reported_by_user_name': reportedByName,
          ReportFields.reason: reportData[ReportFields.reason] ?? '',
          'created_at':
              (reportData[ReportFields.createdAt] as Timestamp?)?.toDate() ?? DateTime.now(),
          ReportFields.status: reportData[ReportFields.status] ?? ReportFields.statusPending,
        });
      }

      return reports;
    } catch (e) {
      AppLogger.e('getReportsForCommunity', e);
      return [];
    }
  }

  /// Marks [reportId] as dismissed.
  Future<bool> dismissReport(String reportId) async {
    try {
      await firestore
          .collection(FirestoreCollections.memberReports)
          .doc(reportId)
          .update({ReportFields.status: ReportFields.statusDismissed});
      AppLogger.d('Report dismissed: $reportId');
      return true;
    } catch (e) {
      AppLogger.e('dismissReport', e);
      return false;
    }
  }

  /// Returns the count of pending reports for [communityId].
  Future<int> getPendingReportsCount(String communityId) async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.memberReports)
          .where(ReportFields.communityId, isEqualTo: communityId)
          .where(ReportFields.status, isEqualTo: ReportFields.statusPending)
          .get();
      return snap.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  /// Resolves the display name for [userId] from Firestore, or returns a
  /// generic fallback.
  Future<String> _getDisplayNameForUser(String userId) async {
    if (userId.isEmpty) return 'Usuario';
    try {
      final doc = await firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .get();
      if (!doc.exists) return 'Usuario';
      return _displayName(doc.data()!);
    } catch (_) {
      return 'Usuario';
    }
  }

  /// Extracts a human-readable name from a Firestore user document.
  String _displayName(Map<String, dynamic> data) =>
      data['name'] as String? ??
      data['displayName'] as String? ??
      (data['email'] as String?)?.split('@')[0] ??
      'Usuario';

  Map<String, dynamic> _userMapFrom(String uid, Map<String, dynamic> data) => {
        'uid': uid,
        'name': _displayName(data),
        'email': data['email'] as String? ?? '',
      };

  /// Generates a cryptographically secure 32-character alphanumeric token.
  String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
