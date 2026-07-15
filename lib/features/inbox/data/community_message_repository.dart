import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/data/mappers/community_inbox_mapper.dart';
import 'package:guardian/shared/domain/community_inbox_item.dart';

/// Inbox items at `users/{uid}/community_messages` (messages + membership events).
class CommunityMessageRepository {
  CommunityMessageRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _inbox(String userId) =>
      _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.communityMessages);

  /// Soft-inbox stream; maps Firestore docs to [CommunityInboxItem] (no SDK types).
  Stream<List<CommunityInboxItem>> watchInbox(String userId, {int limit = 80}) {
    return _inbox(userId)
        .orderBy(CommunityInboxFields.createdAt, descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map(CommunityInboxMapper.fromDoc).toList(),
        );
  }

  /// True while the user has at least one unread inbox item (messages + membership).
  /// Client-side over [watchInbox] so missing `read` counts as unread and no extra index.
  Stream<bool> watchHasUnread(String userId) {
    return watchInbox(userId).map(
      (items) => items.any((m) => m.isUnread),
    );
  }

  Future<void> markRead(String userId, String inboxDocId) async {
    await _inbox(userId).doc(inboxDocId).update({CommunityInboxFields.read: true});
  }

  /// After kick: remove soft-inbox history for [communityId], keep `member_removed`.
  Future<void> purgeCommunityMessagesExceptRemoval({
    required String userId,
    required String communityId,
  }) async {
    final bySingular = await _inbox(userId)
        .where(CommunityInboxFields.communityId, isEqualTo: communityId)
        .get();
    final byArray = await _inbox(userId)
        .where(CommunityInboxFields.communityIds, arrayContains: communityId)
        .get();

    final docs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in [...bySingular.docs, ...byArray.docs]) {
      docs[d.id] = d;
    }

    final toDelete = <DocumentReference>[];
    for (final d in docs.values) {
      final kind = d.data()[CommunityInboxFields.kind] as String?;
      if (kind == CommunityInboxFields.kindMemberRemoved) continue;
      toDelete.add(d.reference);
    }

    for (var i = 0; i < toDelete.length; i += 400) {
      final batch = _firestore.batch();
      final chunk = toDelete.skip(i).take(400);
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Remove / trim alert_inbox copies that reference [communityId].
  Future<void> purgeAlertInboxForCommunity({
    required String userId,
    required String communityId,
  }) async {
    final snap = await _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.alertInbox)
        .where(AlertInboxFields.communityIds, arrayContains: communityId)
        .get();

    for (var i = 0; i < snap.docs.length; i += 400) {
      final batch = _firestore.batch();
      final chunk = snap.docs.skip(i).take(400);
      for (final d in chunk) {
        final ids = List<String>.from(
          (d.data()[AlertInboxFields.communityIds] as List?)?.map((e) => e.toString()) ??
              const [],
        );
        final remaining = ids.where((id) => id != communityId).toList();
        if (remaining.isEmpty) {
          batch.delete(d.reference);
        } else {
          batch.update(d.reference, {AlertInboxFields.communityIds: remaining});
        }
      }
      await batch.commit();
    }
  }

  Future<List<String>> queryManagerUserIds({
    required String communityId,
    required bool isEntity,
  }) async {
    final role = isEntity ? MemberFields.roleOfficial : MemberFields.roleAdmin;
    final snap = await _firestore
        .collection(FirestoreCollections.communityMembers)
        .where(MemberFields.communityId, isEqualTo: communityId)
        .where(MemberFields.role, isEqualTo: role)
        .get();
    return snap.docs
        .map((d) => d.data()[MemberFields.userId]?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Soft membership notification for target and/or managers.
  Future<void> writeMembershipNotification({
    required String targetUserId,
    required String kind,
    required String communityId,
    required String communityName,
    bool isEntity = false,
    String? actorId,
    String? actorName,
    String? subjectName,
    String? role,
    String? previousRole,
    bool notifyTarget = true,
    bool notifyManagers = true,
  }) async {
    final fallback = isEntity ? 'tu reporte' : 'tu comunidad';
    final name = communityName.trim().isEmpty ? fallback : communityName.trim();
    final who = (subjectName ?? actorName)?.trim();
    final subject = (who == null || who.isEmpty) ? 'Alguien' : who;

    final batch = _firestore.batch();
    var writes = 0;

    if (notifyTarget && targetUserId.isNotEmpty) {
      final copy = _targetCopy(
        kind: kind,
        isEntity: isEntity,
        name: name,
        role: role,
        previousRole: previousRole,
      );
      if (copy != null) {
        final docId = _docId(kind, communityId, targetUserId);
        batch.set(_inbox(targetUserId).doc(docId), {
          CommunityInboxFields.kind: kind,
          CommunityInboxFields.communityId: communityId,
          CommunityInboxFields.communityName: name,
          CommunityInboxFields.communityIds: [communityId],
          CommunityInboxFields.title: copy.$1,
          CommunityInboxFields.body: copy.$2,
          CommunityInboxFields.senderId: actorId,
          CommunityInboxFields.senderName: actorName,
          CommunityInboxFields.role: role,
          CommunityInboxFields.previousRole: previousRole,
          CommunityInboxFields.targetUserId: targetUserId,
          CommunityInboxFields.read: false,
          CommunityInboxFields.createdAt: Timestamp.now(),
          'is_entity': isEntity,
          'subject_name': subjectName,
        });
        writes++;
      }
    }

    if (notifyManagers) {
      final managerKind = kind == CommunityInboxFields.kindMemberLeft
          ? CommunityInboxFields.kindMemberLeft
          : kind;
      final copy = _managerCopy(
        kind: managerKind,
        isEntity: isEntity,
        name: name,
        subject: subject,
        role: role,
        previousRole: previousRole,
      );
      if (copy != null) {
        final managers = await queryManagerUserIds(
          communityId: communityId,
          isEntity: isEntity,
        );
        final exclude = <String>{
          if (targetUserId.isNotEmpty) targetUserId,
          if (actorId != null && actorId.isNotEmpty) actorId,
        };
        for (final managerId in managers) {
          if (exclude.contains(managerId)) continue;
          final docId = _docId(managerKind, communityId, managerId);
          batch.set(_inbox(managerId).doc(docId), {
            CommunityInboxFields.kind: managerKind,
            CommunityInboxFields.communityId: communityId,
            CommunityInboxFields.communityName: name,
            CommunityInboxFields.communityIds: [communityId],
            CommunityInboxFields.title: copy.$1,
            CommunityInboxFields.body: copy.$2,
            CommunityInboxFields.senderId: actorId,
            CommunityInboxFields.senderName: actorName,
            CommunityInboxFields.role: role,
            CommunityInboxFields.previousRole: previousRole,
            CommunityInboxFields.targetUserId: targetUserId,
            CommunityInboxFields.read: false,
            CommunityInboxFields.createdAt: Timestamp.now(),
            'is_entity': isEntity,
            'subject_name': subjectName,
          });
          writes++;
        }
      }
    }

    if (writes > 0) {
      await batch.commit();
    }
  }

  String _docId(String kind, String communityId, String userId) =>
      '${kind}_${communityId}_${DateTime.now().microsecondsSinceEpoch}_${userId.hashCode.abs()}';

  (String, String)? _targetCopy({
    required String kind,
    required bool isEntity,
    required String name,
    String? role,
    String? previousRole,
  }) {
    if (isEntity) {
      switch (kind) {
        case CommunityInboxFields.kindMemberAdded:
          return ('Te agregaron a un reporte', 'Ahora formas parte de $name.');
        case CommunityInboxFields.kindMemberRemoved:
          return (
            'Te eliminaron de un reporte',
            'Ya no formas parte del reporte $name.',
          );
        case CommunityInboxFields.kindRoleChanged:
          final prev = _roleLabel(previousRole);
          final next = _roleLabel(role);
          final body = previousRole != null && previousRole.isNotEmpty
              ? 'En el reporte $name pasaste de $prev a $next.'
              : 'Tu rol cambió en el reporte $name. Ahora eres $next.';
          return ('Tu rol cambió', body);
        default:
          return null;
      }
    }

    switch (kind) {
      case CommunityInboxFields.kindMemberAdded:
        return ('Te agregaron a una comunidad', 'Ahora formas parte de $name.');
      case CommunityInboxFields.kindMemberRemoved:
        return ('Te eliminaron de una comunidad', 'Ya no formas parte de $name.');
      case CommunityInboxFields.kindRoleChanged:
        final prev = _roleLabel(previousRole);
        final next = _roleLabel(role);
        final body = previousRole != null && previousRole.isNotEmpty
            ? 'En $name pasaste de $prev a $next.'
            : 'En $name tu rol ahora es $next.';
        return ('Tu rol cambió', body);
      default:
        return null;
    }
  }

  (String, String)? _managerCopy({
    required String kind,
    required bool isEntity,
    required String name,
    required String subject,
    String? role,
    String? previousRole,
  }) {
    if (isEntity) {
      switch (kind) {
        case CommunityInboxFields.kindMemberAdded:
          return (
            'Nuevo miembro en reporte',
            '$subject se unió al reporte $name.',
          );
        case CommunityInboxFields.kindMemberRemoved:
          return (
            'Miembro eliminado',
            '$subject fue eliminado/a del reporte $name.',
          );
        case CommunityInboxFields.kindMemberLeft:
          return ('Miembro salió', '$subject abandonó el reporte $name.');
        case CommunityInboxFields.kindRoleChanged:
          final prev = _roleLabel(previousRole);
          final next = _roleLabel(role);
          final body = previousRole != null && previousRole.isNotEmpty
              ? '$subject pasó de $prev a $next en el reporte $name.'
              : '$subject ahora es $next en el reporte $name.';
          return ('Cambio de rol', body);
        default:
          return null;
      }
    }

    switch (kind) {
      case CommunityInboxFields.kindMemberAdded:
        return ('Nuevo miembro', '$subject se unió a la comunidad $name.');
      case CommunityInboxFields.kindMemberRemoved:
        return (
          'Miembro eliminado',
          '$subject fue eliminado/a de la comunidad $name.',
        );
      case CommunityInboxFields.kindMemberLeft:
        return ('Miembro salió', '$subject abandonó la comunidad $name.');
      case CommunityInboxFields.kindRoleChanged:
        final prev = _roleLabel(previousRole);
        final next = _roleLabel(role);
        final body = previousRole != null && previousRole.isNotEmpty
            ? '$subject pasó de $prev a $next en $name.'
            : '$subject ahora es $next en $name.';
        return ('Cambio de rol', body);
      default:
        return null;
    }
  }

  String _roleLabel(String? role) {
    switch ((role ?? '').toLowerCase()) {
      case MemberFields.roleAdmin:
        return 'Administrador';
      case MemberFields.roleOfficial:
        return 'Oficial';
      case MemberFields.roleMember:
        return 'Miembro';
      default:
        return role?.isNotEmpty == true ? role! : 'Miembro';
    }
  }
}
