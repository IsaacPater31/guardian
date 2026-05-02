import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../core/entity_definitions.dart';
import '../models/join_result.dart';
import '../models/member_report_model.dart';
import '../repositories/community_repository.dart';
import 'alert_service.dart';

/// Business rules for communities, memberships, invites, and moderation.
///
/// **Why a service:** applies authz (admin vs member, entity constraints) and
/// coordinates several repository calls; [CommunityRepository] stays Firestore-only.
class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  final CommunityRepository _repo = CommunityRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _invalidateAlertCommunityCache() {
    AlertService().invalidateCommunityCache();
  }

  // ─── Entity bootstrap ────────────────────────────────────────────────────

  Future<bool> initializeEntityCommunities() async {
    try {
      bool createdAny = false;

      for (final entity in EntityDefinitions.defaultEntities) {
        final existing = await _repo.queryCommunitiesByNameAndEntity(
          entity[CommunityFields.name] as String,
          true,
        );

        if (existing.docs.isEmpty) {
          await _repo.addCommunity(EntityDefinitions.toFirestore(entity));
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

  Future<void> ensureUserInEntities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        AppLogger.w('ensureUserInEntities: no authenticated user');
        return;
      }

      var entitiesSnap = await _repo.fetchAllEntityCommunities();

      if (entitiesSnap.docs.isEmpty) {
        AppLogger.w('No entities found — seeding now');
        await initializeEntityCommunities();
        entitiesSnap = await _repo.fetchAllEntityCommunities();

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
    List<QueryDocumentSnapshot<Map<String, dynamic>>> entities,
  ) async {
    final batch = _repo.createBatch();
    int added = 0;

    for (final entityDoc in entities) {
      final communityId = entityDoc.id;

      final existingMember = await _repo.findMembership(userId, communityId);

      if (existingMember.docs.isEmpty) {
        final ref = _repo.firestore.collection(FirestoreCollections.communityMembers).doc();
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
      _invalidateAlertCommunityCache();
      AppLogger.d('User added to $added entities');
    } else {
      AppLogger.d('User already belongs to all entities');
    }
  }

  // ─── Community queries ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMyCommunities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      return _repo.fetchUserCommunities(userId);
    } catch (e) {
      AppLogger.e('getMyCommunities', e);
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> getMyCommunitiesStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _repo.watchMembershipsForUser(userId).asyncMap((_) => getMyCommunities());
  }

  // ─── Alert recipients ────────────────────────────────────────────────────

  Future<List<String>> getAlertRecipients(String communityId) async {
    try {
      final community = await _repo.getCommunityById(communityId);
      if (community == null) return [];

      final isEntity = community.isEntity;
      final snap = await _repo.queryMembersInCommunity(
        communityId,
        roleIs: isEntity ? MemberFields.roleOfficial : null,
      );

      return snap.docs
          .map((doc) {
            final data = doc.data();
            return data[MemberFields.userId] as String? ?? '';
          })
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      AppLogger.e('getAlertRecipients', e);
      return [];
    }
  }

  // ─── Official members ────────────────────────────────────────────────────

  Future<bool> addOfficialMember(String userId, String communityId) async {
    try {
      final community = await _repo.getCommunityById(communityId);
      if (community == null) {
        AppLogger.e('addOfficialMember: community not found');
        return false;
      }
      if (!community.isEntity) {
        AppLogger.e('addOfficialMember: target is not an entity');
        return false;
      }

      final existing = await _repo.findMembership(userId, communityId);

      if (existing.docs.isNotEmpty) {
        await _repo.updateMemberDoc(existing.docs.first.reference, {
          MemberFields.role: MemberFields.roleOfficial,
        });
        AppLogger.d('Updated user to official member');
      } else {
        await _repo.addMember({
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

  // ─── Create / update / delete community ─────────────────────────────────

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

      final ref = await _repo.addCommunity(data);

      await _repo.addMember({
        MemberFields.userId: userId,
        MemberFields.communityId: ref.id,
        MemberFields.joinedAt: Timestamp.now(),
        MemberFields.role: MemberFields.roleAdmin,
      });

      _invalidateAlertCommunityCache();
      AppLogger.d('Community created: $name (${ref.id})');
      return ref.id;
    } catch (e) {
      AppLogger.e('createCommunity', e);
      return null;
    }
  }

  Future<String?> generateInviteLink(String communityId) async {
    try {
      final community = await _repo.getCommunityById(communityId);
      if (community == null) {
        AppLogger.e('generateInviteLink: community not found');
        return null;
      }
      if (community.isEntity) {
        AppLogger.e('generateInviteLink: entities cannot have invite links');
        return null;
      }

      final token = _generateToken();
      final expiresAt = DateTime.now().add(AppDurations.inviteExpiry);

      await _repo.setInvite(token, {
        InviteFields.communityId: communityId,
        InviteFields.expiresAt: Timestamp.fromDate(expiresAt),
      });

      return '${AppUrls.inviteLinkBase}$token';
    } catch (e) {
      AppLogger.e('generateInviteLink', e);
      return null;
    }
  }

  Future<bool> validateUserExists(String email) async {
    try {
      final snap = await _repo.queryUsersByEmail(email.toLowerCase().trim());
      return snap.docs.isNotEmpty;
    } catch (e) {
      AppLogger.e('validateUserExists', e);
      return false;
    }
  }

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
        final membersSnap = await _repo.queryMembersByCommunity(excludeCommunityId);
        existingMemberIds = membersSnap.docs
            .map((d) => d.data()[MemberFields.userId] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
      }

      final emailSnap = await _repo.queryUsersByEmail(trimmed, limit: 5);
      for (final doc in emailSnap.docs) {
        final uid = doc.id;
        if (uid == userId || existingMemberIds.contains(uid) || addedIds.contains(uid)) continue;
        addedIds.add(uid);
        final data = doc.data();
        results.add(_userMapFrom(uid, data));
      }

      if (results.length < 10) {
        final nameSnap = await _repo.queryUsersLimited(100);

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

  Future<void> emitMemberAddedWelcomeSignal({
    required String targetUserId,
    required String communityId,
  }) async {
    try {
      final commSnap = await _repo.getCommunitySnapshot(communityId);
      final commName = commSnap.data()?[CommunityFields.name] as String? ?? '';
      await _repo.addMemberAddedSignal({
        MemberAddedSignalFields.targetUserId: targetUserId,
        MemberAddedSignalFields.communityId: communityId,
        MemberAddedSignalFields.communityName: commName,
        MemberAddedSignalFields.createdAt: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.e('emitMemberAddedWelcomeSignal', e);
    }
  }

  Future<JoinResult> addMemberDirectly(String communityId, String targetUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return JoinResult(success: false, message: 'No hay usuario autenticado');
      }

      if (await getUserRole(communityId) != MemberFields.roleAdmin) {
        return JoinResult(success: false, message: 'Solo administradores pueden agregar miembros');
      }

      final targetDoc = await _repo.getUserProfile(targetUserId);
      if (!targetDoc.exists) {
        return JoinResult(success: false, message: 'Usuario no encontrado');
      }

      final existing = await _repo.findMembership(targetUserId, communityId);

      if (existing.docs.isNotEmpty) {
        final role =
            existing.docs.first.data()[MemberFields.role] as String? ?? MemberFields.roleMember;
        return JoinResult(
          success: true,
          alreadyMember: true,
          role: role,
          message: 'Este usuario ya es miembro de la comunidad',
        );
      }

      await _repo.addMember({
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

  // ─── Invites ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getInviteInfo(String token) async {
    try {
      final inviteDoc = await _repo.getInvite(token);

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

  Future<JoinResult> joinCommunityByToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return JoinResult(success: false, message: 'No hay usuario autenticado');
      }

      final inviteDoc = await _repo.getInvite(token);
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

      final existing = await _repo.findMembership(userId, communityId);

      if (existing.docs.isNotEmpty) {
        final role =
            existing.docs.first.data()[MemberFields.role] as String? ?? MemberFields.roleMember;
        return JoinResult(
          success: true,
          alreadyMember: true,
          role: role,
          message: role == MemberFields.roleAdmin
              ? 'Ya eres administrador de esta comunidad'
              : 'Ya eres miembro de esta comunidad',
        );
      }

      await _repo.addMember({
        MemberFields.userId: userId,
        MemberFields.communityId: communityId,
        MemberFields.joinedAt: Timestamp.now(),
        MemberFields.role: MemberFields.roleMember,
      });

      _invalidateAlertCommunityCache();
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

  // ─── Roles ───────────────────────────────────────────────────────────────

  Future<String?> getUserRole(String communityId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final snap = await _repo.findMembership(userId, communityId);

      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data()[MemberFields.role] as String? ?? MemberFields.roleMember;
    } catch (e) {
      AppLogger.e('getUserRole', e);
      return null;
    }
  }

  // ─── Leave / delete ─────────────────────────────────────────────────────

  Future<bool> leaveCommunity(String communityId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Usuario no autenticado');

    final communityDoc = await _repo.getCommunitySnapshot(communityId);

    if (!communityDoc.exists) throw Exception('La comunidad no existe');
    if (communityDoc.data()?[CommunityFields.isEntity] ?? false) {
      throw Exception('No se puede abandonar una entidad oficial');
    }

    final memberSnap = await _repo.findMembership(userId, communityId);

    if (memberSnap.docs.isEmpty) throw Exception('No eres miembro de esta comunidad');

    final role =
        memberSnap.docs.first.data()[MemberFields.role] as String? ?? MemberFields.roleMember;
    if (role == MemberFields.roleAdmin) {
      final adminsSnap = await _repo.queryAdminsInCommunity(communityId);

      if (adminsSnap.docs.length <= 1) {
        throw Exception('Eres el único administrador. Promueve a otro miembro antes de salir.');
      }
    }

    await _repo.deleteMemberDoc(memberSnap.docs.first.reference);
    _invalidateAlertCommunityCache();
    return true;
  }

  Future<bool> deleteCommunity(String communityId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        AppLogger.e('deleteCommunity: no authenticated user');
        return false;
      }

      final communityDoc = await _repo.getCommunitySnapshot(communityId);

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

      final batch = _repo.createBatch();

      final membersSnap = await _repo.queryMembersByCommunity(communityId);
      for (final doc in membersSnap.docs) {
        batch.delete(doc.reference);
      }

      final invitesSnap = await _repo.queryInvitesForCommunity(communityId);
      for (final doc in invitesSnap.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(communityDoc.reference);
      await batch.commit();

      _invalidateAlertCommunityCache();
      AppLogger.d('Community deleted: $communityId');
      return true;
    } catch (e) {
      AppLogger.e('deleteCommunity', e);
      return false;
    }
  }

  Future<bool> isCreator(String communityId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final doc = await _repo.getCommunitySnapshot(communityId);

      if (!doc.exists) return false;
      return (doc.data()?[CommunityFields.createdBy] as String?) == userId;
    } catch (e) {
      AppLogger.e('isCreator', e);
      return false;
    }
  }

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

      final ok = await _repo.patchCommunity(communityId, updateData);
      if (ok) AppLogger.d('Community updated: $communityId');
      return ok;
    } catch (e) {
      AppLogger.e('updateCommunity', e);
      return false;
    }
  }

  // ─── Members ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCommunityMembers(String communityId) async {
    try {
      final membersSnap = await _repo.queryMembersByCommunity(communityId);

      if (membersSnap.docs.isEmpty) return [];

      final members = <Map<String, dynamic>>[];

      for (final memberDoc in membersSnap.docs) {
        final memberData = memberDoc.data();
        final uid = memberData[MemberFields.userId] as String? ?? '';
        if (uid.isEmpty) continue;

        String? userName;
        String? userEmail;

        try {
          final userDoc = await _repo.getUserProfile(uid);
          if (userDoc.exists) {
            final data = userDoc.data()!;
            userName = _displayName(data);
            userEmail = data['email'] as String?;
          }
        } catch (_) {}

        if (userName == null && uid == _auth.currentUser?.uid) {
          userName = _auth.currentUser?.displayName;
          userEmail ??= _auth.currentUser?.email;
        }

        members.add({
          'member_id': memberDoc.id,
          MemberFields.userId: uid,
          'user_name': userName ?? userEmail?.split('@')[0] ?? 'Usuario',
          'user_email': userEmail ?? '',
          MemberFields.role: memberData[MemberFields.role] as String? ?? MemberFields.roleMember,
          'joined_at':
              (memberData[MemberFields.joinedAt] as Timestamp?)?.toDate() ?? DateTime.now(),
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

      final targetSnap = await _repo.findMembership(targetUserId, communityId);

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

      await _repo.deleteMemberDoc(targetSnap.docs.first.reference);
      AppLogger.d('Member removed from $communityId');
      return true;
    } catch (e) {
      AppLogger.e('removeMember', e);
      return false;
    }
  }

  Future<bool> promoteToAdmin(String communityId, String targetUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      if (await getUserRole(communityId) != MemberFields.roleAdmin) {
        AppLogger.w('promoteToAdmin: caller is not admin');
        return false;
      }

      final targetSnap = await _repo.findMembership(targetUserId, communityId);

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

      await _repo.updateMemberDoc(targetSnap.docs.first.reference, {
        MemberFields.role: MemberFields.roleAdmin,
      });
      AppLogger.d('Member promoted to admin');
      return true;
    } catch (e) {
      AppLogger.e('promoteToAdmin', e);
      return false;
    }
  }

  // ─── Member reports ─────────────────────────────────────────────────────

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

      await _repo.addMemberReport(report.toFirestore());
      AppLogger.d('Member report created');
      return true;
    } catch (e) {
      AppLogger.e('reportMember', e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getReportsForCommunity(String communityId) async {
    try {
      if (await getUserRole(communityId) != MemberFields.roleAdmin) {
        AppLogger.w('getReportsForCommunity: caller is not admin');
        return [];
      }

      final reportsSnap = await _repo.queryPendingReportsForCommunity(communityId);

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

  Future<bool> dismissReport(String reportId) async {
    try {
      await _repo.updateReport(reportId, {ReportFields.status: ReportFields.statusDismissed});
      AppLogger.d('Report dismissed: $reportId');
      return true;
    } catch (e) {
      AppLogger.e('dismissReport', e);
      return false;
    }
  }

  Future<int> getPendingReportsCount(String communityId) async {
    try {
      final snap = await _repo.queryPendingReportsForCount(communityId);
      return snap.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Future<String> _getDisplayNameForUser(String userId) async {
    if (userId.isEmpty) return 'Usuario';
    try {
      final doc = await _repo.getUserProfile(userId);
      if (!doc.exists) return 'Usuario';
      return _displayName(doc.data()!);
    } catch (_) {
      return 'Usuario';
    }
  }

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

  String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
