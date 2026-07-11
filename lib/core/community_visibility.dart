import 'app_constants.dart';

/// Whether a community map represents an official support entity.
///
/// Entities (`is_entity: true`) are created only from the web admin and
/// surface in the app as the "Reportes" section (e.g. "Reporte Policía").
/// Users join them exclusively via invite link/code.
// entidad genere sus propios códigos/enlaces de invitación.
bool communityMapIsEntity(Map<String, dynamic> community) {
  final value =
      community[CommunityFields.isEntity] ?? community['is_entity'];
  return value == true;
}

/// User-facing community lists show only normal communities (no entities).
List<Map<String, dynamic>> visibleUserCommunities(
  Iterable<Map<String, dynamic>> communities,
) {
  return communities
      .where((community) => !communityMapIsEntity(community))
      .toList();
}

/// Entities the user belongs to — rendered as the "Reportes" section.
List<Map<String, dynamic>> entityUserCommunities(
  Iterable<Map<String, dynamic>> communities,
) {
  return communities.where(communityMapIsEntity).toList();
}
