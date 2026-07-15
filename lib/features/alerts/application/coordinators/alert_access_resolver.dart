import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/alerts/domain/alert_model.dart';
import 'package:guardian/features/communities/data/community_repository.dart';
import 'package:guardian/features/auth/application/user_service.dart';

/// Resolved community membership used for alert feed visibility filtering.
class UserCommunityAccess {
  final List<String> communityIds;
  final Map<String, String> rolesByCommunityId;

  const UserCommunityAccess({
    required this.communityIds,
    required this.rolesByCommunityId,
  });
}

/// Caches the current user's viewable community ids / roles and applies
/// alert feed visibility rules (permissions + community membership).
class AlertAccessResolver {
  final CommunityRepository _communityRepository;
  final UserService _userService;

  List<String>? _cachedUserCommunityIds;
  Map<String, String>? _cachedUserRolesByCommunityId;
  DateTime? _cacheTimestamp;

  AlertAccessResolver({
    CommunityRepository? communityRepository,
    UserService? userService,
  })  : _communityRepository = communityRepository ?? CommunityRepository(),
        _userService = userService ?? UserService();

  void invalidate() {
    _cachedUserCommunityIds = null;
    _cachedUserRolesByCommunityId = null;
    _cacheTimestamp = null;
  }

  Future<UserCommunityAccess> getUserCommunityAccess() async {
    if (_cachedUserCommunityIds != null &&
        _cachedUserRolesByCommunityId != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) <
            AppDurations.communityIdCache) {
      return UserCommunityAccess(
        communityIds: _cachedUserCommunityIds!,
        rolesByCommunityId: _cachedUserRolesByCommunityId!,
      );
    }

    try {
      final uid = _userService.currentUser?.uid;
      if (uid == null) {
        return const UserCommunityAccess(
          communityIds: [],
          rolesByCommunityId: <String, String>{},
        );
      }

      final communities = await _communityRepository.fetchUserCommunities(uid);

      final memberships = await _communityRepository.listMembershipsForUser(uid);
      _cachedUserRolesByCommunityId = {
        for (final m in memberships) m.communityId: m.role,
      };

      // Comunidades cuyas alertas puede VER el usuario en sus feeds:
      // - normales: cualquier miembro;
      // - entidades: solo official (los reportes de otros ciudadanos
      //   no deben llegarle a miembros rasos ni a roles legacy de admin).
      _cachedUserCommunityIds = communities
          .where((c) {
            if (!c.isEntity) return true;
            final role = _cachedUserRolesByCommunityId![c.id];
            return role == MemberFields.roleOfficial;
          })
          .map((c) => c.id!)
          .toList();

      _cacheTimestamp = DateTime.now();
      return UserCommunityAccess(
        communityIds: _cachedUserCommunityIds!,
        rolesByCommunityId: _cachedUserRolesByCommunityId!,
      );
    } catch (e) {
      AppLogger.e('AlertAccessResolver.getUserCommunityAccess', e);
      return UserCommunityAccess(
        communityIds: _cachedUserCommunityIds ?? const [],
        rolesByCommunityId: _cachedUserRolesByCommunityId ?? const {},
      );
    }
  }

  List<AlertModel> filterByPermissionsAndCommunity(
    List<AlertModel> alerts,
    UserCommunityAccess access,
  ) {
    final membershipSet = access.communityIds.toSet();

    return alerts.where((alert) {
      if (!_userService.canUserViewAlert(
        alert.userId,
        alert.userEmail,
        alert.isAnonymous,
      )) {
        return false;
      }
      if (alert.communityIds.isEmpty) return true;

      // El emisor siempre ve sus propias alertas/reportes (p. ej. un ciudadano
      // que reportó a una entidad puede seguir el estado aunque no reciba
      // los reportes de otros).
      if (_userService.isUserOwnerOfAlert(alert.userId, alert.userEmail)) {
        return true;
      }

      return alert.communityIds.any(membershipSet.contains);
    }).toList();
  }
}
