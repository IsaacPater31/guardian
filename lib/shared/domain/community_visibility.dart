import 'package:guardian/features/communities/domain/community_model.dart';

/// Whether a [CommunityModel] is an official support entity.
bool communityIsEntity(CommunityModel community) => community.isEntity;

/// User-facing community lists show only normal communities (no entities).
List<CommunityModel> visibleUserCommunities(
  Iterable<CommunityModel> communities,
) {
  return communities.where((c) => !c.isEntity).toList();
}

/// Entities the user belongs to — rendered as the "Reportes" section.
List<CommunityModel> entityUserCommunities(
  Iterable<CommunityModel> communities,
) {
  return communities.where((c) => c.isEntity).toList();
}
