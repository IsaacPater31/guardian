import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/communities/data/community_repository.dart';

/// Creates communities and initial admin memberships.
class CommunityLifecycle {
  CommunityLifecycle({
    CommunityRepository? repository,
    void Function()? onMembershipChanged,
  })  : _repo = repository ?? CommunityRepository(),
        _onMembershipChanged = onMembershipChanged;

  final CommunityRepository _repo;
  final void Function()? _onMembershipChanged;

  Future<String?> createCommunityForUser({
    required String userId,
    required String name,
    String? description,
    int? iconCodePoint,
    String? iconColor,
    String? defaultSlug,
  }) async {
    final data = <String, dynamic>{
      CommunityFields.name: name,
      CommunityFields.description: description,
      CommunityFields.isEntity: false,
      CommunityFields.createdBy: userId,
      CommunityFields.createdAt: Timestamp.now(),
    };
    if (iconCodePoint != null) data[CommunityFields.iconCodePoint] = iconCodePoint;
    if (iconColor != null) data[CommunityFields.iconColor] = iconColor;
    if (defaultSlug != null) data[CommunityFields.defaultSlug] = defaultSlug;

    final ref = await _repo.addCommunity(data);

    await _repo.addMember({
      MemberFields.userId: userId,
      MemberFields.communityId: ref.id,
      MemberFields.joinedAt: Timestamp.now(),
      MemberFields.role: MemberFields.roleAdmin,
    });

    _onMembershipChanged?.call();
    AppLogger.d('Community created: $name (${ref.id})');
    return ref.id;
  }
}
