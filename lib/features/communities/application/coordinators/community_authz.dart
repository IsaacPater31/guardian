import 'package:firebase_auth/firebase_auth.dart';

import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/features/communities/data/community_repository.dart';
import 'package:guardian/features/communities/domain/user_search_hit.dart';

/// Shared authorization and display helpers for community collaborators.
class CommunityAuthz {
  CommunityAuthz({
    CommunityRepository? repository,
    FirebaseAuth? auth,
  })  : _repo = repository ?? CommunityRepository(),
        _auth = auth ?? FirebaseAuth.instance;

  final CommunityRepository _repo;
  final FirebaseAuth _auth;

  String? get currentUid => _auth.currentUser?.uid;

  Future<bool> isEntityCommunity(String communityId) async {
    final community = await _repo.getCommunityById(communityId);
    return community?.isEntity == true;
  }

  Future<bool> canManageMembership(String communityId, String? role) async {
    if (role == null) return false;
    if (await isEntityCommunity(communityId)) {
      return role == MemberFields.roleOfficial;
    }
    return role == MemberFields.roleAdmin;
  }

  Future<bool> canReviewReports(String communityId, String? role) async {
    if (role == null) return false;
    if (await isEntityCommunity(communityId)) {
      return role == MemberFields.roleOfficial;
    }
    return role == MemberFields.roleAdmin;
  }

  Future<int> countMembersWithRole(String communityId, String role) async {
    final members = await _repo.listMembersByCommunity(communityId);
    return members.where((m) => m.role == role).length;
  }

  String displayName(Map<String, dynamic> data) =>
      data['name'] as String? ??
      data['displayName'] as String? ??
      (data['email'] as String?)?.split('@')[0] ??
      'Usuario';

  Future<String> displayNameForUser(String userId) async {
    if (userId.isEmpty) return 'Usuario';
    try {
      final doc = await _repo.getUserProfile(userId);
      if (!doc.exists) return 'Usuario';
      return displayName(doc.data()!);
    } catch (_) {
      return 'Usuario';
    }
  }

  UserSearchHit userHitFrom(String uid, Map<String, dynamic> data) =>
      UserSearchHit(
        uid: uid,
        name: displayName(data),
        email: data['email'] as String? ?? '',
      );
}
