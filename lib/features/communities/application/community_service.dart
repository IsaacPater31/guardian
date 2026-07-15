import 'package:firebase_auth/firebase_auth.dart';

import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/domain/community_visibility.dart';
import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/communities/domain/community_member_list_item.dart';
import 'package:guardian/features/communities/domain/community_model.dart';
import 'package:guardian/features/communities/domain/join_result.dart';
import 'package:guardian/features/communities/domain/member_report_list_item.dart';
import 'package:guardian/features/communities/domain/user_search_hit.dart';
import 'package:guardian/features/communities/data/community_repository.dart';
import 'package:guardian/shared/domain/member_added_welcome_signal.dart';
import 'package:guardian/features/alerts/application/alert_service.dart';
import 'package:guardian/features/communities/application/coordinators/community_authz.dart';
import 'package:guardian/features/communities/application/coordinators/community_invite_coordinator.dart';
import 'package:guardian/features/communities/application/coordinators/community_lifecycle.dart';
import 'package:guardian/features/communities/application/coordinators/community_membership_admin.dart';
import 'package:guardian/features/communities/application/coordinators/default_community_bootstrap.dart';
import 'package:guardian/features/communities/application/coordinators/member_report_coordinator.dart';
import 'package:guardian/features/auth/application/user_service.dart';

/// Business rules for communities, memberships, invites, and moderation.
///
/// Thin facade over collaborators under [community/]. Public API unchanged.
///
/// **Why a service:** applies authz (admin vs member, entity constraints) and
/// coordinates several repository calls; [CommunityRepository] stays Firestore-only.
class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;

  CommunityService._internal() {
    _repo = CommunityRepository();
    _auth = FirebaseAuth.instance;
    _authz = CommunityAuthz(repository: _repo, auth: _auth);
    _lifecycle = CommunityLifecycle(
      repository: _repo,
      onMembershipChanged: _invalidateAlertCommunityCache,
    );
    _bootstrap = DefaultCommunityBootstrap(
      repository: _repo,
      lifecycle: _lifecycle,
    );
    _membership = CommunityMembershipAdmin(
      repository: _repo,
      authz: _authz,
      auth: _auth,
      onMembershipChanged: _invalidateAlertCommunityCache,
    );
    _invites = CommunityInviteCoordinator(
      repository: _repo,
      authz: _authz,
      auth: _auth,
      getUserRole: _membership.getUserRole,
      onMembershipChanged: _invalidateAlertCommunityCache,
    );
    _reports = MemberReportCoordinator(
      repository: _repo,
      authz: _authz,
      auth: _auth,
      getUserRole: _membership.getUserRole,
    );
  }

  late final CommunityRepository _repo;
  late final FirebaseAuth _auth;
  late final CommunityAuthz _authz;
  late final CommunityLifecycle _lifecycle;
  late final DefaultCommunityBootstrap _bootstrap;
  late final CommunityMembershipAdmin _membership;
  late final CommunityInviteCoordinator _invites;
  late final MemberReportCoordinator _reports;

  void _invalidateAlertCommunityCache() {
    AlertService().invalidateCommunityCache();
  }

  // ─── Community queries ───────────────────────────────────────────────────

  Future<List<CommunityModel>> getMyCommunities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      final communities = await _repo.fetchUserCommunities(userId);
      return visibleUserCommunities(communities);
    } catch (e) {
      AppLogger.e('getMyCommunities', e);
      return [];
    }
  }

  /// Entidades (`is_entity: true`) a las que pertenece el usuario.
  ///
  /// Se muestran en el apartado "Reportes" de Comunidades. El usuario se une
  /// solo por enlace/código de invitación; nunca se crean desde la app.
  Future<List<CommunityModel>> getMyEntityCommunities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      final communities = await _repo.fetchUserCommunities(userId);
      return entityUserCommunities(communities);
    } catch (e) {
      AppLogger.e('getMyEntityCommunities', e);
      return [];
    }
  }

  Stream<List<CommunityModel>> getMyCommunitiesStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _repo.watchMembershipsForUser(userId).asyncMap((_) => getMyCommunities());
  }

  /// All communities the user belongs to (normal + entity) — for inbox scoping.
  Stream<List<CommunityModel>> getAllMyCommunitiesStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _repo.watchMembershipsForUser(userId).asyncMap((_) async {
      try {
        return await _repo.fetchUserCommunities(userId);
      } catch (e) {
        AppLogger.e('getAllMyCommunitiesStream', e);
        return <CommunityModel>[];
      }
    });
  }

  /// Emits when the current user is added to a community (ephemeral signals).
  Stream<MemberAddedWelcomeSignal> watchMyMemberAddedWelcomes() {
    final userId = UserService().currentUserId;
    if (userId == null) return const Stream<MemberAddedWelcomeSignal>.empty();
    return _repo.watchNewMemberAddedSignals(userId);
  }

  Future<void> acknowledgeMemberAddedWelcome(String signalId) {
    return _repo.deleteMemberAddedSignal(signalId);
  }

  // ─── Alert recipients ────────────────────────────────────────────────────

  Future<List<String>> getAlertRecipients(String communityId) async {
    try {
      final members = await _repo.listMembersByCommunity(communityId);
      return members
          .map((m) => m.userId)
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      AppLogger.e('getAlertRecipients', e);
      return [];
    }
  }

  // ─── Default communities (first access) ──────────────────────────────────

  /// Crea las comunidades por defecto si el usuario no pertenece a ninguna.
  ///
  /// Idempotente: reintentos tras fallo de red o sync duplicado no duplican Hogar.
  /// Registro + AuthGate pueden disparar esto a la vez; se serializa por [userId].
  Future<void> ensureDefaultCommunitiesForUser(String userId) =>
      _bootstrap.ensureDefaultCommunitiesForUser(userId);

  // ─── Create / update / delete community ─────────────────────────────────

  Future<String?> createCommunity({
    required String name,
    String? description,
    int? iconCodePoint,
    String? iconColor,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        AppLogger.e('createCommunity: no authenticated user');
        return null;
      }

      return _lifecycle.createCommunityForUser(
        userId: userId,
        name: name,
        description: description,
        iconCodePoint: iconCodePoint,
        iconColor: iconColor,
      );
    } catch (e) {
      AppLogger.e('createCommunity', e);
      return null;
    }
  }

  Future<String?> generateInviteLink(String communityId) =>
      _invites.generateInviteLink(communityId);

  Future<bool> validateUserExists(String email) =>
      _invites.validateUserExists(email);

  Future<List<UserSearchHit>> searchUsers(
    String query, {
    String? excludeCommunityId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      final trimmed = query.trim().toLowerCase();
      if (trimmed.isEmpty || trimmed.length < 2) return [];

      final results = <UserSearchHit>[];
      final addedIds = <String>{};

      Set<String> existingMemberIds = {};
      if (excludeCommunityId != null) {
        final membersSnap =
            await _repo.queryMembersByCommunity(excludeCommunityId);
        existingMemberIds = membersSnap.docs
            .map((d) => d.data()[MemberFields.userId] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
      }

      final emailSnap = await _repo.queryUsersByEmail(trimmed, limit: 5);
      for (final doc in emailSnap.docs) {
        final uid = doc.id;
        if (uid == userId ||
            existingMemberIds.contains(uid) ||
            addedIds.contains(uid)) {
          continue;
        }
        addedIds.add(uid);
        results.add(_authz.userHitFrom(uid, doc.data()));
      }

      if (results.length < 10) {
        final nameSnap = await _repo.queryUsersLimited(100);

        for (final doc in nameSnap.docs) {
          if (results.length >= 10) break;
          final uid = doc.id;
          if (uid == userId ||
              existingMemberIds.contains(uid) ||
              addedIds.contains(uid)) {
            continue;
          }

          final data = doc.data();
          final name = (_authz.displayName(data)).toLowerCase();
          final email = (data['email'] as String? ?? '').toLowerCase();

          if (name.contains(trimmed) || email.contains(trimmed)) {
            addedIds.add(uid);
            results.add(_authz.userHitFrom(uid, data));
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
    String? subjectName,
  }) =>
      _invites.emitMemberAddedWelcomeSignal(
        targetUserId: targetUserId,
        communityId: communityId,
        subjectName: subjectName,
      );

  Future<JoinResult> addMemberDirectly(String communityId, String targetUserId) =>
      _invites.addMemberDirectly(communityId, targetUserId);

  // ─── Invites ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getInviteInfo(String token) =>
      _invites.getInviteInfo(token);

  Future<JoinResult> joinCommunityByToken(String token) =>
      _invites.joinCommunityByToken(token);

  // ─── Roles ───────────────────────────────────────────────────────────────

  Future<String?> getUserRole(String communityId) =>
      _membership.getUserRole(communityId);

  // ─── Leave / delete ─────────────────────────────────────────────────────

  Future<bool> leaveCommunity(String communityId) =>
      _membership.leaveCommunity(communityId);

  Future<bool> deleteCommunity(String communityId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        AppLogger.e('deleteCommunity: no authenticated user');
        return false;
      }

      final community = await _repo.getCommunityById(communityId);

      if (community == null) {
        AppLogger.e('deleteCommunity: community not found');
        return false;
      }

      if (community.createdBy != userId) {
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

      batch.delete(_repo.communityDocRef(communityId));
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

      final community = await _repo.getCommunityById(communityId);
      if (community == null) return false;
      return community.createdBy == userId;
    } catch (e) {
      AppLogger.e('isCreator', e);
      return false;
    }
  }

  Future<bool> updateCommunity(
    String communityId, {
    String? name,
    String? description,
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

  Future<List<CommunityMemberListItem>> getCommunityMembers(
    String communityId,
  ) =>
      _membership.getCommunityMembers(communityId);

  Future<bool> removeMember(String communityId, String targetUserId) =>
      _membership.removeMember(communityId, targetUserId);

  Future<bool> promoteToAdmin(String communityId, String targetUserId) =>
      _membership.promoteToAdmin(communityId, targetUserId);

  // ─── Member reports ─────────────────────────────────────────────────────

  Future<bool> reportMember({
    required String communityId,
    required String reportedUserId,
    required String reason,
  }) =>
      _reports.reportMember(
        communityId: communityId,
        reportedUserId: reportedUserId,
        reason: reason,
      );

  Future<List<MemberReportListItem>> getReportsForCommunity(
    String communityId,
  ) =>
      _reports.getReportsForCommunity(communityId);

  Future<bool> dismissReport(String reportId) => _reports.dismissReport(reportId);

  Future<int> getPendingReportsCount(String communityId) =>
      _reports.getPendingReportsCount(communityId);
}
