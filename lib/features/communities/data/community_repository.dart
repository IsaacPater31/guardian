import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/communities/data/community_fetch_mixin.dart';
import 'package:guardian/features/communities/domain/community_member_model.dart';
import 'package:guardian/features/communities/domain/community_model.dart';
import 'package:guardian/shared/data/mappers/community_mapper.dart';
import 'package:guardian/shared/data/mappers/member_added_welcome_mapper.dart';
import 'package:guardian/shared/data/mappers/membership_mapper.dart';
import 'package:guardian/shared/domain/member_added_welcome_signal.dart';

/// Firestore access for communities, memberships, invites, user directory,
/// reports, and related signals.
///
/// **Why a repository:** isolates SDK calls and collection/field names from
/// [CommunityService], so rules (who may delete, entity vs normal, etc.) live
/// only in the service layer.
///
class CommunityRepository with CommunityFetchMixin {
  static final CommunityRepository _instance = CommunityRepository._internal();
  factory CommunityRepository() => _instance;
  CommunityRepository._internal();

  @override
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // ─── Community documents ─────────────────────────────────────────────────

  Future<CommunityModel?> getCommunityById(String communityId) async {
    try {
      final doc = await firestore
          .collection(FirestoreCollections.communities)
          .doc(communityId)
          .get();
      if (!doc.exists) return null;
      return CommunityMapper.fromDoc(doc);
    } catch (e) {
      AppLogger.e('CommunityRepository.getCommunityById', e);
      return null;
    }
  }

  Future<DocumentReference<Map<String, dynamic>>> addCommunity(
    Map<String, dynamic> data,
  ) {
    return firestore.collection(FirestoreCollections.communities).add(data);
  }

  Future<bool> patchCommunity(String communityId, Map<String, dynamic> data) async {
    try {
      await firestore.collection(FirestoreCollections.communities).doc(communityId).update(data);
      return true;
    } catch (e) {
      AppLogger.e('CommunityRepository.patchCommunity', e);
      return false;
    }
  }

  /// Alias for callers that expect the older [updateCommunity] name.
  Future<bool> updateCommunity(String communityId, Map<String, dynamic> data) =>
      patchCommunity(communityId, data);

  /// Deletes a single community document (no cascade). Prefer service-level delete.
  Future<bool> deleteCommunityDocOnly(String communityId) async {
    try {
      await firestore.collection(FirestoreCollections.communities).doc(communityId).delete();
      return true;
    } catch (e) {
      AppLogger.e('CommunityRepository.deleteCommunityDocOnly', e);
      return false;
    }
  }

  /// Alias for the legacy [deleteCommunity] method (single doc only).
  Future<bool> deleteCommunity(String communityId) => deleteCommunityDocOnly(communityId);

  Future<List<CommunityModel>> getAllCommunities() async {
    try {
      final snapshot = await firestore.collection(FirestoreCollections.communities).get();
      return snapshot.docs.map(CommunityMapper.fromDoc).toList();
    } catch (e) {
      AppLogger.e('CommunityRepository.getAllCommunities', e);
      return [];
    }
  }

  // ─── Memberships ─────────────────────────────────────────────────────────

  Future<QuerySnapshot<Map<String, dynamic>>> findMembership(
    String userId,
    String communityId,
  ) {
    return firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.userId, isEqualTo: userId)
        .where(MemberFields.communityId, isEqualTo: communityId)
        .limit(1)
        .get();
  }

  /// Typed membership lookup (null if the user is not a member).
  Future<CommunityMemberModel?> findMembershipOf(
    String userId,
    String communityId,
  ) async {
    final snap = await findMembership(userId, communityId);
    if (snap.docs.isEmpty) return null;
    return MembershipMapper.fromDoc(snap.docs.first);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMembershipsForUser(String userId) {
    return firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.userId, isEqualTo: userId)
        .snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> queryMembershipsForUser(
    String userId, {
    int? limit,
  }) {
    Query<Map<String, dynamic>> q = firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.userId, isEqualTo: userId);
    if (limit != null) {
      q = q.limit(limit);
    }
    return q.get();
  }

  Future<List<CommunityMemberModel>> listMembershipsForUser(
    String userId, {
    int? limit,
  }) async {
    final snap = await queryMembershipsForUser(userId, limit: limit);
    return snap.docs.map(MembershipMapper.fromDoc).toList();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> queryDefaultCommunityForUser(
    String userId,
    String defaultSlug,
  ) {
    return firestore
        .collection(FirestoreCollections.communities)
        .where(CommunityFields.createdBy, isEqualTo: userId)
        .where(CommunityFields.defaultSlug, isEqualTo: defaultSlug)
        .limit(1)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> queryMembersInCommunity(
    String communityId, {
    String? roleIs,
  }) {
    Query<Map<String, dynamic>> q = firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.communityId, isEqualTo: communityId);
    if (roleIs != null) {
      q = q.where(MemberFields.role, isEqualTo: roleIs);
    }
    return q.get();
  }

  Future<DocumentReference<Map<String, dynamic>>> addMember(Map<String, dynamic> data) {
    return firestore.collection(FirestoreCollections.communityMembers).add(data);
  }

  Future<void> updateMemberDoc(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) {
    return ref.update(data);
  }

  Future<void> deleteMemberDoc(DocumentReference<Map<String, dynamic>> ref) {
    return ref.delete();
  }

  DocumentReference<Map<String, dynamic>> membershipDocRef(String membershipId) {
    return firestore
        .collection(FirestoreCollections.communityMembers)
        .doc(membershipId);
  }

  DocumentReference<Map<String, dynamic>> communityDocRef(String communityId) {
    return firestore.collection(FirestoreCollections.communities).doc(communityId);
  }

  Future<void> updateMembershipById(
    String membershipId,
    Map<String, dynamic> data,
  ) {
    return membershipDocRef(membershipId).update(data);
  }

  Future<void> deleteMembershipById(String membershipId) {
    return membershipDocRef(membershipId).delete();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> queryMembersByCommunity(String communityId) {
    return firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.communityId, isEqualTo: communityId)
        .get();
  }

  /// Typed members of a community (prefer over [queryMembersByCommunity]).
  Future<List<CommunityMemberModel>> listMembersByCommunity(
    String communityId,
  ) async {
    final snap = await queryMembersByCommunity(communityId);
    return snap.docs.map(MembershipMapper.fromDoc).toList();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> queryAdminsInCommunity(String communityId) {
    return firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.communityId, isEqualTo: communityId)
        .where(MemberFields.role, isEqualTo: MemberFields.roleAdmin)
        .get();
  }

  WriteBatch createBatch() => firestore.batch();

  // ─── Invites ─────────────────────────────────────────────────────────────

  Future<void> setInvite(String token, Map<String, dynamic> data) {
    return firestore.collection(FirestoreCollections.invites).doc(token).set(data);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getInvite(String token) {
    return firestore.collection(FirestoreCollections.invites).doc(token).get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> queryInvitesForCommunity(String communityId) {
    return firestore
        .collection(FirestoreCollections.invites)
        .where(InviteFields.communityId, isEqualTo: communityId)
        .get();
  }

  // ─── Users directory ─────────────────────────────────────────────────────

  Future<QuerySnapshot<Map<String, dynamic>>> queryUsersByEmail(
    String email, {
    int limit = 1,
  }) {
    return firestore
        .collection(FirestoreCollections.users)
        .where('email', isEqualTo: email)
        .limit(limit)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> queryUsersLimited(int limit) {
    return firestore.collection(FirestoreCollections.users).limit(limit).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserProfile(String uid) {
    return firestore.collection(FirestoreCollections.users).doc(uid).get();
  }

  // ─── Signals & reports ────────────────────────────────────────────────────

  Future<void> addMemberAddedSignal(Map<String, dynamic> data) {
    return firestore.collection(FirestoreCollections.memberAddedSignals).add(data);
  }

  /// Newly added welcome signals for [userId] (does not delete).
  Stream<MemberAddedWelcomeSignal> watchNewMemberAddedSignals(String userId) {
    return firestore
        .collection(FirestoreCollections.memberAddedSignals)
        .where(MemberAddedSignalFields.targetUserId, isEqualTo: userId)
        .snapshots()
        .expand((snapshot) {
          return snapshot.docChanges
              .where((change) => change.type == DocumentChangeType.added)
              .map((change) => MemberAddedWelcomeMapper.fromDoc(change.doc));
        });
  }

  Future<void> deleteMemberAddedSignal(String signalId) {
    return firestore
        .collection(FirestoreCollections.memberAddedSignals)
        .doc(signalId)
        .delete();
  }

  Future<void> addMemberReport(Map<String, dynamic> data) {
    return firestore.collection(FirestoreCollections.memberReports).add(data);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> queryPendingReportsForCommunity(
    String communityId,
  ) {
    return firestore
        .collection(FirestoreCollections.memberReports)
        .where(ReportFields.communityId, isEqualTo: communityId)
        .where(ReportFields.status, isEqualTo: ReportFields.statusPending)
        .orderBy(ReportFields.createdAt, descending: true)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> queryPendingReportsForCount(String communityId) {
    return firestore
        .collection(FirestoreCollections.memberReports)
        .where(ReportFields.communityId, isEqualTo: communityId)
        .where(ReportFields.status, isEqualTo: ReportFields.statusPending)
        .get();
  }

  Future<void> updateReport(String reportId, Map<String, dynamic> data) {
    return firestore.collection(FirestoreCollections.memberReports).doc(reportId).update(data);
  }
}
