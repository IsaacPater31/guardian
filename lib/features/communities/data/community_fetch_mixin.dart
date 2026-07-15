import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:guardian/features/communities/domain/community_model.dart';
import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/data/mappers/community_mapper.dart';

/// Mixin that provides a reusable helper for fetching the communities
/// a given user belongs to from Firestore.
///
/// The fetch-memberships → batch-fetch-communities → sort pattern lives on
/// [CommunityRepository] via this mixin so all callers share one implementation.
mixin CommunityFetchMixin {
  FirebaseFirestore get firestore;

  /// Returns all communities that [userId] belongs to, as [CommunityModel].
  ///
  /// Sorted alphabetically by name.
  Future<List<CommunityModel>> fetchUserCommunities(String userId) async {
    final membersSnap = await firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.userId, isEqualTo: userId)
        .get();

    if (membersSnap.docs.isEmpty) return [];

    final communityIds = membersSnap.docs
        .map((d) => d.data()[MemberFields.communityId] as String)
        .toList();

    if (communityIds.isEmpty) return [];

    final communities = <CommunityModel>[];

    for (int i = 0; i < communityIds.length; i += 10) {
      final batch = communityIds.skip(i).take(10).toList();
      final snap = await firestore
          .collection(FirestoreCollections.communities)
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      communities.addAll(snap.docs.map(CommunityMapper.fromDoc));
    }

    communities.sort((a, b) => a.name.compareTo(b.name));
    return communities;
  }

  /// Validates that the given community IDs still exist in Firestore and
  /// returns only the valid subset.
  Future<List<String>> validateCommunityIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final valid = <String>[];

    for (int i = 0; i < ids.length; i += 10) {
      final batch = ids.skip(i).take(10).toList();
      final snap = await firestore
          .collection(FirestoreCollections.communities)
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      valid.addAll(snap.docs.map((d) => d.id));
    }

    return valid;
  }
}
