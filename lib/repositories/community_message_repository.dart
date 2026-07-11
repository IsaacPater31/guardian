import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_constants.dart';

/// Inbox items at `users/{uid}/community_messages` (messages + membership events).
class CommunityMessageRepository {
  CommunityMessageRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _inbox(String userId) =>
      _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('community_messages');

  Stream<List<Map<String, dynamic>>> watchInbox(String userId, {int limit = 80}) {
    return _inbox(userId)
        .orderBy(CommunityInboxFields.createdAt, descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            return {
              'id': d.id,
              ...data,
            };
          }).toList(),
        );
  }

  /// True while the user has at least one unread inbox item (messages + membership).
  /// Client-side over [watchInbox] so missing `read` counts as unread and no extra index.
  Stream<bool> watchHasUnread(String userId) {
    return watchInbox(userId).map(
      (items) => items.any((m) => m[CommunityInboxFields.read] != true),
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

  /// Soft membership notification for the affected user.
  Future<void> writeMembershipNotification({
    required String targetUserId,
    required String kind,
    required String communityId,
    required String communityName,
    String? actorId,
    String? actorName,
    String? role,
    String? previousRole,
  }) async {
    final name = communityName.trim().isEmpty ? 'tu comunidad' : communityName.trim();
    late final String title;
    late final String body;

    switch (kind) {
      case CommunityInboxFields.kindMemberAdded:
        title = 'Te agregaron a una comunidad';
        body = 'Ahora formas parte de $name.';
        break;
      case CommunityInboxFields.kindMemberRemoved:
        title = 'Te eliminaron de una comunidad';
        body = 'Ya no formas parte de $name.';
        break;
      case CommunityInboxFields.kindRoleChanged:
        title = 'Tu rol cambió';
        final prev = _roleLabel(previousRole);
        final next = _roleLabel(role);
        body = previousRole != null && previousRole.isNotEmpty
            ? 'En $name pasaste de $prev a $next.'
            : 'En $name tu rol ahora es $next.';
        break;
      default:
        return;
    }

    final docId =
        '${kind}_${communityId}_${DateTime.now().microsecondsSinceEpoch}_${targetUserId.hashCode.abs()}';
    // Timestamp.now() (not serverTimestamp): orderBy(created_at) on Android
    // excludes docs until the server fills the field, which can drop the ADDED event.
    await _inbox(targetUserId).doc(docId).set({
      CommunityInboxFields.kind: kind,
      CommunityInboxFields.communityId: communityId,
      CommunityInboxFields.communityName: name,
      CommunityInboxFields.communityIds: [communityId],
      CommunityInboxFields.title: title,
      CommunityInboxFields.body: body,
      CommunityInboxFields.senderId: actorId,
      CommunityInboxFields.senderName: actorName,
      CommunityInboxFields.role: role,
      CommunityInboxFields.previousRole: previousRole,
      CommunityInboxFields.targetUserId: targetUserId,
      CommunityInboxFields.read: false,
      CommunityInboxFields.createdAt: Timestamp.now(),
    });
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
