import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_constants.dart';

/// Mixin that provides a reusable helper for fetching the communities
/// a given user belongs to from Firestore.
///
/// The same fetch-memberships → batch-fetch-communities → sort pattern
/// was previously duplicated in [CommunityService], [QuickAlertConfigService],
/// and [SwipeAlertConfigService]. This mixin is the single canonical
/// implementation.
///
/// Classes that use this mixin gain access to [fetchUserCommunities] and the
/// private batch-fetching helpers.
mixin CommunityFetchMixin {
  FirebaseFirestore get firestore;

  /// Returns all communities that [userId] belongs to.
  ///
  /// Entities are sorted first, then alphabetically by name.
  ///
  /// [extraFields] lets callers request additional Firestore fields to be
  /// included in each returned map (in addition to the default set).
  Future<List<Map<String, dynamic>>> fetchUserCommunities(
    String userId, {
    List<String> extraFields = const [],
  }) async {
    // 1. Fetch all membership records for this user.
    final membersSnap = await firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.userId, isEqualTo: userId)
        .get();

    if (membersSnap.docs.isEmpty) return [];

    final communityIds = membersSnap.docs
        .map((d) => d.data()[MemberFields.communityId] as String)
        .toList();

    if (communityIds.isEmpty) return [];

    // 2. Batch-fetch community documents (Firestore whereIn limit = 10).
    final communities = <Map<String, dynamic>>[];

    for (int i = 0; i < communityIds.length; i += 10) {
      final batch = communityIds.skip(i).take(10).toList();
      final snap = await firestore
          .collection(FirestoreCollections.communities)
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      communities.addAll(snap.docs.map((doc) {
        final data = doc.data();
        final base = <String, dynamic>{
          'id': doc.id,
          CommunityFields.name: data[CommunityFields.name],
          CommunityFields.description: data[CommunityFields.description],
          CommunityFields.isEntity: data[CommunityFields.isEntity] ?? false,
          CommunityFields.allowForwardToEntities:
              data[CommunityFields.allowForwardToEntities] ?? true,
          CommunityFields.iconCodePoint: data[CommunityFields.iconCodePoint],
          CommunityFields.iconColor: data[CommunityFields.iconColor],
        };
        // Merge any extra fields requested by the caller.
        for (final field in extraFields) {
          base[field] = data[field];
        }
        return base;
      }));
    }

    // 3. Sort: entities first, then alphabetical by name.
    communities.sort((a, b) {
      final aIsEntity = a[CommunityFields.isEntity] as bool;
      final bIsEntity = b[CommunityFields.isEntity] as bool;
      if (aIsEntity != bIsEntity) return bIsEntity ? 1 : -1;
      return (a[CommunityFields.name] as String)
          .compareTo(b[CommunityFields.name] as String);
    });

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
