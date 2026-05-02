import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../core/mixins/community_fetch_mixin.dart';
import '../models/community_model.dart';

/// Firestore access for communities, memberships, invites, user directory,
/// reports, and related signals.
///
/// **Why a repository:** isolates SDK calls and collection/field names from
/// [CommunityService], so rules (who may delete, entity vs normal, etc.) live
/// only in the service layer.
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
      return CommunityModel.fromFirestore(doc);
    } catch (e) {
      AppLogger.e('CommunityRepository.getCommunityById', e);
      return null;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getCommunitySnapshot(
    String communityId,
  ) {
    return firestore.collection(FirestoreCollections.communities).doc(communityId).get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> queryCommunitiesByNameAndEntity(
    String name,
    bool isEntity,
  ) {
    return firestore
        .collection(FirestoreCollections.communities)
        .where(CommunityFields.name, isEqualTo: name)
        .where(CommunityFields.isEntity, isEqualTo: isEntity)
        .limit(1)
        .get();
  }

  Future<DocumentReference<Map<String, dynamic>>> addCommunity(
    Map<String, dynamic> data,
  ) {
    return firestore.collection(FirestoreCollections.communities).add(data);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchAllEntityCommunities() {
    return firestore
        .collection(FirestoreCollections.communities)
        .where(CommunityFields.isEntity, isEqualTo: true)
        .get();
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
      return snapshot.docs.map(CommunityModel.fromFirestore).toList();
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

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMembershipsForUser(String userId) {
    return firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.userId, isEqualTo: userId)
        .snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> queryMembershipsForUser(String userId) {
    return firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.userId, isEqualTo: userId)
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

  Future<QuerySnapshot<Map<String, dynamic>>> queryMembersByCommunity(String communityId) {
    return firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.communityId, isEqualTo: communityId)
        .get();
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
