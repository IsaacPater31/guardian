import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/inbox/data/community_message_repository.dart';
import 'package:guardian/features/communities/data/community_repository.dart';
import 'package:guardian/features/communities/domain/community_member_list_item.dart';
import 'package:guardian/features/communities/application/coordinators/community_authz.dart';

/// Membership role lookup, leave/remove/promote, and member listing.
class CommunityMembershipAdmin {
  CommunityMembershipAdmin({
    CommunityRepository? repository,
    CommunityAuthz? authz,
    FirebaseAuth? auth,
    CommunityMessageRepository? messageRepository,
    void Function()? onMembershipChanged,
  })  : _repo = repository ?? CommunityRepository(),
        _authz = authz ?? CommunityAuthz(),
        _auth = auth ?? FirebaseAuth.instance,
        _messages = messageRepository ?? CommunityMessageRepository(),
        _onMembershipChanged = onMembershipChanged;

  final CommunityRepository _repo;
  final CommunityAuthz _authz;
  final FirebaseAuth _auth;
  final CommunityMessageRepository _messages;
  final void Function()? _onMembershipChanged;

  Future<String?> getUserRole(String communityId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final membership = await _repo.findMembershipOf(userId, communityId);
      return membership?.role;
    } catch (e) {
      AppLogger.e('getUserRole', e);
      return null;
    }
  }

  Future<bool> leaveCommunity(String communityId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Usuario no autenticado');

    final community = await _repo.getCommunityById(communityId);

    if (community == null) throw Exception('La comunidad no existe');

    final membership = await _repo.findMembershipOf(userId, communityId);

    if (membership == null || membership.id == null) {
      throw Exception('No eres miembro de esta comunidad');
    }

    final role = membership.role;
    final isEntity = community.isEntity;
    if (isEntity) {
      if (role == MemberFields.roleOfficial) {
        final officialsCount = await _authz.countMembersWithRole(
          communityId,
          MemberFields.roleOfficial,
        );
        if (officialsCount <= 1) {
          throw Exception(
            'Eres el único oficial. Agrega otro oficial antes de salir.',
          );
        }
      }
    } else if (role == MemberFields.roleAdmin) {
      final adminsSnap = await _repo.queryAdminsInCommunity(communityId);
      if (adminsSnap.docs.length <= 1) {
        throw Exception(
          'Eres el único administrador. Promueve a otro miembro antes de salir.',
        );
      }
    }

    final commName = community.name;
    String? subjectName;
    try {
      final profile = await _repo.getUserProfile(userId);
      if (profile.exists) {
        subjectName = _authz.displayName(profile.data() ?? {});
      }
    } catch (_) {}

    // Notify managers BEFORE delete. If notify fails, do not leave
    // (managers would miss the event with no recovery path).
    try {
      await _messages.writeMembershipNotification(
        targetUserId: userId,
        kind: CommunityInboxFields.kindMemberLeft,
        communityId: communityId,
        communityName: commName,
        isEntity: isEntity,
        actorId: userId,
        actorName: subjectName,
        subjectName: subjectName,
        notifyTarget: false,
        notifyManagers: true,
      );
    } catch (e) {
      AppLogger.e('leaveCommunity notify managers', e);
      throw Exception(
        'No se pudo notificar a los gestores. Intenta salir de nuevo.',
      );
    }

    await _repo.deleteMembershipById(membership.id!);
    _onMembershipChanged?.call();
    return true;
  }

  Future<List<CommunityMemberListItem>> getCommunityMembers(
    String communityId,
  ) async {
    try {
      final membersSnap = await _repo.queryMembersByCommunity(communityId);

      if (membersSnap.docs.isEmpty) return [];

      final members = <CommunityMemberListItem>[];

      for (final memberDoc in membersSnap.docs) {
        final memberData = memberDoc.data();
        final uid = memberData[MemberFields.userId] as String? ?? '';
        if (uid.isEmpty) continue;

        String? userName;
        String? userEmail;

        try {
          final userDoc = await _repo.getUserProfile(uid);
          if (userDoc.exists) {
            final data = userDoc.data()!;
            userName = _authz.displayName(data);
            userEmail = data['email'] as String?;
          }
        } catch (_) {}

        if (userName == null && uid == _auth.currentUser?.uid) {
          userName = _auth.currentUser?.displayName;
          userEmail ??= _auth.currentUser?.email;
        }

        members.add(
          CommunityMemberListItem(
            memberId: memberDoc.id,
            userId: uid,
            userName: userName ?? userEmail?.split('@')[0] ?? 'Usuario',
            userEmail: userEmail ?? '',
            role: memberData[MemberFields.role] as String? ??
                MemberFields.roleMember,
            joinedAt: (memberData[MemberFields.joinedAt] as Timestamp?)
                    ?.toDate() ??
                DateTime.now(),
          ),
        );
      }

      const roleOrder = {
        MemberFields.roleOfficial: 0,
        MemberFields.roleAdmin: 0,
        MemberFields.roleMember: 1,
      };

      members.sort((a, b) {
        final aOrd = roleOrder[a.role] ?? 3;
        final bOrd = roleOrder[b.role] ?? 3;
        if (aOrd != bOrd) return aOrd.compareTo(bOrd);
        return a.userName.compareTo(b.userName);
      });

      return members;
    } catch (e) {
      AppLogger.e('getCommunityMembers', e);
      return [];
    }
  }

  Future<bool> removeMember(String communityId, String targetUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final callerRole = await getUserRole(communityId);
      if (!await _authz.canManageMembership(communityId, callerRole)) {
        AppLogger.w('removeMember: caller is not manager');
        return false;
      }
      if (targetUserId == userId) {
        AppLogger.w('removeMember: cannot remove self');
        return false;
      }

      final target = await _repo.findMembershipOf(targetUserId, communityId);

      if (target == null || target.id == null) {
        AppLogger.w('removeMember: target is not a member');
        return false;
      }

      final targetRole = target.role;
      final isEntity = await _authz.isEntityCommunity(communityId);
      if (!isEntity && targetRole == MemberFields.roleAdmin) {
        AppLogger.w('removeMember: cannot remove another admin');
        return false;
      }
      if (isEntity && targetRole == MemberFields.roleOfficial) {
        final officialsCount = await _authz.countMembersWithRole(
          communityId,
          MemberFields.roleOfficial,
        );
        if (officialsCount <= 1) {
          AppLogger.w('removeMember: cannot remove last official');
          return false;
        }
      }

      // Notify + purge BEFORE delete. If notify fails, do not remove membership
      // (user would lose access with no kick notice / leftover inbox).
      try {
        final community = await _repo.getCommunityById(communityId);
        final commName = community?.name ?? '';
        String? subjectName;
        try {
          final profile = await _repo.getUserProfile(targetUserId);
          if (profile.exists) {
            subjectName = _authz.displayName(profile.data() ?? {});
          }
        } catch (_) {}
        await _messages.writeMembershipNotification(
          targetUserId: targetUserId,
          kind: CommunityInboxFields.kindMemberRemoved,
          communityId: communityId,
          communityName: commName,
          isEntity: isEntity,
          actorId: userId,
          subjectName: subjectName,
        );
        await _messages.purgeCommunityMessagesExceptRemoval(
          userId: targetUserId,
          communityId: communityId,
        );
        await _messages.purgeAlertInboxForCommunity(
          userId: targetUserId,
          communityId: communityId,
        );
      } catch (e) {
        AppLogger.e('removeMember notify/purge', e);
        return false;
      }

      await _repo.deleteMembershipById(target.id!);
      AppLogger.d('Member removed from $communityId');
      return true;
    } catch (e) {
      AppLogger.e('removeMember', e);
      return false;
    }
  }

  Future<bool> promoteToAdmin(String communityId, String targetUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final callerRole = await getUserRole(communityId);
      if (!await _authz.canManageMembership(communityId, callerRole)) {
        AppLogger.w('promoteToAdmin: caller is not manager');
        return false;
      }

      final target = await _repo.findMembershipOf(targetUserId, communityId);

      if (target == null || target.id == null) {
        AppLogger.w('promoteToAdmin: target is not a member');
        return false;
      }

      final isEntity = await _authz.isEntityCommunity(communityId);
      final targetRole = target.role;
      final destinationRole = isEntity
          ? MemberFields.roleOfficial
          : MemberFields.roleAdmin;
      if (targetRole == destinationRole) {
        AppLogger.d('promoteToAdmin: user already has target role');
        return true;
      }

      await _repo.updateMembershipById(target.id!, {
        MemberFields.role: destinationRole,
      });
      AppLogger.d('Member promoted to $destinationRole');
      try {
        final community = await _repo.getCommunityById(communityId);
        final commName = community?.name ?? '';
        String? subjectName;
        try {
          final profile = await _repo.getUserProfile(targetUserId);
          if (profile.exists) {
            subjectName = _authz.displayName(profile.data() ?? {});
          }
        } catch (_) {}
        await _messages.writeMembershipNotification(
          targetUserId: targetUserId,
          kind: CommunityInboxFields.kindRoleChanged,
          communityId: communityId,
          communityName: commName,
          isEntity: isEntity,
          actorId: userId,
          subjectName: subjectName,
          role: destinationRole,
          previousRole: targetRole,
        );
      } catch (e) {
        AppLogger.e('promoteToAdmin notify', e);
      }
      return true;
    } catch (e) {
      AppLogger.e('promoteToAdmin', e);
      return false;
    }
  }
}
