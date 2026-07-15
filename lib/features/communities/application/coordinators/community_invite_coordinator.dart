import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/communities/domain/join_result.dart';
import 'package:guardian/features/inbox/data/community_message_repository.dart';
import 'package:guardian/features/communities/data/community_repository.dart';
import 'package:guardian/features/communities/application/coordinators/community_authz.dart';

/// Invite links, joins, and direct member additions.
class CommunityInviteCoordinator {
  CommunityInviteCoordinator({
    CommunityRepository? repository,
    CommunityAuthz? authz,
    FirebaseAuth? auth,
    CommunityMessageRepository? messageRepository,
    Future<String?> Function(String communityId)? getUserRole,
    void Function()? onMembershipChanged,
  })  : _repo = repository ?? CommunityRepository(),
        _authz = authz ?? CommunityAuthz(),
        _auth = auth ?? FirebaseAuth.instance,
        _messages = messageRepository ?? CommunityMessageRepository(),
        _getUserRole = getUserRole,
        _onMembershipChanged = onMembershipChanged;

  final CommunityRepository _repo;
  final CommunityAuthz _authz;
  final FirebaseAuth _auth;
  final CommunityMessageRepository _messages;
  final Future<String?> Function(String communityId)? _getUserRole;
  final void Function()? _onMembershipChanged;

  Future<String?> generateInviteLink(String communityId) async {
    try {
      final community = await _repo.getCommunityById(communityId);
      if (community == null) {
        AppLogger.e('generateInviteLink: community not found');
        return null;
      }

      final token = _generateToken();
      final expiresAt = DateTime.now().add(AppDurations.inviteExpiry);

      await _repo.setInvite(token, {
        InviteFields.communityId: communityId,
        InviteFields.expiresAt: Timestamp.fromDate(expiresAt),
      });

      return '${AppUrls.inviteLinkBase}$token';
    } catch (e) {
      AppLogger.e('generateInviteLink', e);
      return null;
    }
  }

  Future<bool> validateUserExists(String email) async {
    try {
      final snap = await _repo.queryUsersByEmail(email.toLowerCase().trim());
      return snap.docs.isNotEmpty;
    } catch (e) {
      AppLogger.e('validateUserExists', e);
      return false;
    }
  }

  Future<void> emitMemberAddedWelcomeSignal({
    required String targetUserId,
    required String communityId,
    String? subjectName,
  }) async {
    final community = await _repo.getCommunityById(communityId);
    final commName = community?.name ?? '';
    final isEntity = community?.isEntity == true;

    // Inbox notify first — must not depend on ephemeral welcome signal.
    try {
      await _messages.writeMembershipNotification(
        targetUserId: targetUserId,
        kind: CommunityInboxFields.kindMemberAdded,
        communityId: communityId,
        communityName: commName,
        isEntity: isEntity,
        actorId: _auth.currentUser?.uid,
        subjectName: subjectName,
      );
    } catch (e) {
      AppLogger.e('emitMemberAddedWelcomeSignal inbox', e);
      rethrow;
    }

    try {
      await _repo.addMemberAddedSignal({
        MemberAddedSignalFields.targetUserId: targetUserId,
        MemberAddedSignalFields.communityId: communityId,
        MemberAddedSignalFields.communityName: commName,
        MemberAddedSignalFields.createdAt: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.e('emitMemberAddedWelcomeSignal snackbar signal', e);
    }
  }

  Future<JoinResult> addMemberDirectly(String communityId, String targetUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return JoinResult(success: false, message: 'No hay usuario autenticado');
      }

      final callerRole = await _resolveUserRole(communityId);
      if (!await _authz.canManageMembership(communityId, callerRole)) {
        return JoinResult(
          success: false,
          message: 'No tienes permisos para agregar miembros',
        );
      }

      final targetDoc = await _repo.getUserProfile(targetUserId);
      if (!targetDoc.exists) {
        return JoinResult(success: false, message: 'Usuario no encontrado');
      }

      final existing = await _repo.findMembershipOf(targetUserId, communityId);

      if (existing != null) {
        return JoinResult(
          success: true,
          alreadyMember: true,
          role: existing.role,
          message: 'Este usuario ya es miembro de la comunidad',
        );
      }

      await _repo.addMember({
        MemberFields.userId: targetUserId,
        MemberFields.communityId: communityId,
        MemberFields.joinedAt: Timestamp.now(),
        MemberFields.role: MemberFields.roleMember,
      });

      final targetName = _authz.displayName(targetDoc.data() ?? {});
      AppLogger.d('User $targetName added to community');

      await emitMemberAddedWelcomeSignal(
        targetUserId: targetUserId,
        communityId: communityId,
        subjectName: targetName,
      );

      return JoinResult(
        success: true,
        role: MemberFields.roleMember,
        message: '$targetName ha sido agregado a la comunidad',
      );
    } catch (e) {
      AppLogger.e('addMemberDirectly', e);
      return JoinResult(success: false, message: 'Error al agregar miembro');
    }
  }

  Future<Map<String, dynamic>?> getInviteInfo(String token) async {
    try {
      final inviteDoc = await _repo.getInvite(token);

      if (!inviteDoc.exists) {
        AppLogger.e('Invite token not found');
        return null;
      }

      final data = inviteDoc.data();
      final communityId = data?[InviteFields.communityId] as String?;
      final expiresAt = (data?[InviteFields.expiresAt] as Timestamp?)?.toDate();

      if (communityId == null || expiresAt == null) {
        AppLogger.e('Invalid invite data');
        return null;
      }

      if (DateTime.now().isAfter(expiresAt)) {
        AppLogger.w('Invite token expired');
        return null;
      }

      return {
        InviteFields.communityId: communityId,
        InviteFields.expiresAt: expiresAt,
        'is_valid': true,
      };
    } catch (e) {
      AppLogger.e('getInviteInfo', e);
      return null;
    }
  }

  Future<JoinResult> joinCommunityByToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return JoinResult(success: false, message: 'No hay usuario autenticado');
      }

      final inviteDoc = await _repo.getInvite(token);
      if (!inviteDoc.exists) {
        return JoinResult(success: false, message: 'Token de invitación no válido');
      }

      final data = inviteDoc.data();
      final communityId = data?[InviteFields.communityId] as String?;
      final expiresAt = (data?[InviteFields.expiresAt] as Timestamp?)?.toDate();

      if (communityId == null || expiresAt == null) {
        return JoinResult(success: false, message: 'Datos de invitación inválidos');
      }

      if (DateTime.now().isAfter(expiresAt)) {
        return JoinResult(success: false, message: 'El link de invitación ha expirado');
      }

      final existing = await _repo.findMembershipOf(userId, communityId);

      if (existing != null) {
        return JoinResult(
          success: true,
          alreadyMember: true,
          role: existing.role,
          message: existing.role == MemberFields.roleAdmin
              ? 'Ya eres administrador de esta comunidad'
              : 'Ya eres miembro de esta comunidad',
        );
      }

      await _repo.addMember({
        MemberFields.userId: userId,
        MemberFields.communityId: communityId,
        MemberFields.joinedAt: Timestamp.now(),
        MemberFields.role: MemberFields.roleMember,
      });

      _onMembershipChanged?.call();
      AppLogger.d('User joined community via token');

      String? subjectName;
      try {
        final profile = await _repo.getUserProfile(userId);
        if (profile.exists) {
          subjectName = _authz.displayName(profile.data() ?? {});
        }
      } catch (_) {}

      await emitMemberAddedWelcomeSignal(
        targetUserId: userId,
        communityId: communityId,
        subjectName: subjectName,
      );

      return JoinResult(
        success: true,
        alreadyMember: false,
        role: MemberFields.roleMember,
        message: 'Te has unido exitosamente a la comunidad',
      );
    } catch (e) {
      AppLogger.e('joinCommunityByToken', e);
      return JoinResult(success: false, message: 'Error al unirse a la comunidad');
    }
  }

  Future<String?> _resolveUserRole(String communityId) {
    final getter = _getUserRole;
    if (getter != null) return getter(communityId);

    final userId = _auth.currentUser?.uid;
    if (userId == null) return Future.value(null);
    return _repo.findMembershipOf(userId, communityId).then((m) => m?.role);
  }

  String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
