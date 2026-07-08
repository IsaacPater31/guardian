import 'app_constants.dart';

/// Whether a community map represents an official support entity.
bool communityMapIsEntity(Map<String, dynamic> community) {
  final value =
      community[CommunityFields.isEntity] ?? community['is_entity'];
  return value == true;
}

/// User-facing lists hide official entity communities in this product iteration.
List<Map<String, dynamic>> visibleUserCommunities(
  Iterable<Map<String, dynamic>> communities,
) {
  return communities
      .where((community) => !communityMapIsEntity(community))
      .toList();
}
