import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/communities/domain/default_communities.dart';
import 'package:guardian/features/communities/data/community_repository.dart';
import 'package:guardian/features/communities/application/coordinators/community_lifecycle.dart';

/// Ensures first-access default communities exist for a user (idempotent).
class DefaultCommunityBootstrap {
  DefaultCommunityBootstrap({
    CommunityRepository? repository,
    CommunityLifecycle? lifecycle,
  })  : _repo = repository ?? CommunityRepository(),
        _lifecycle = lifecycle ?? CommunityLifecycle();

  final CommunityRepository _repo;
  final CommunityLifecycle _lifecycle;

  /// Serializes [ensureDefaultCommunitiesForUser] per uid (registro + AuthGate).
  final Map<String, Future<void>> _inFlight = {};

  Future<void> ensureDefaultCommunitiesForUser(String userId) {
    final existing = _inFlight[userId];
    if (existing != null) return existing;

    final future = _ensureDefaultCommunitiesForUserImpl(userId).whenComplete(() {
      _inFlight.remove(userId);
    });
    _inFlight[userId] = future;
    return future;
  }

  Future<void> _ensureDefaultCommunitiesForUserImpl(String userId) async {
    try {
      final memberships = await _repo.listMembershipsForUser(userId, limit: 1);
      if (memberships.isNotEmpty) return;

      for (final template in DefaultCommunities.templates) {
        // Re-check per slug in case a parallel caller already created it.
        final existing = await _repo.queryDefaultCommunityForUser(
          userId,
          template.slug,
        );
        if (existing.docs.isNotEmpty) continue;

        final membershipsAgain =
            await _repo.listMembershipsForUser(userId, limit: 1);
        if (membershipsAgain.isNotEmpty) return;

        await _lifecycle.createCommunityForUser(
          userId: userId,
          name: template.name,
          description: template.description,
          iconCodePoint: template.iconCodePoint,
          iconColor: template.iconColor,
          defaultSlug: template.slug,
        );
      }
    } catch (e) {
      AppLogger.e('ensureDefaultCommunitiesForUser', e);
    }
  }
}
