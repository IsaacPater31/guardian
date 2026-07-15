import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/domain/community_inbox_item.dart';

/// Maps `users/{uid}/community_messages` documents ↔ [CommunityInboxItem].
class CommunityInboxMapper {
  CommunityInboxMapper._();

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static CommunityInboxItem fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return fromMap(doc.id, data);
  }

  static CommunityInboxItem fromMap(String id, Map<String, dynamic> data) {
    return CommunityInboxItem(
      id: id,
      kind: data[CommunityInboxFields.kind] as String?,
      messageId: data[CommunityInboxFields.messageId] as String?,
      communityId: data[CommunityInboxFields.communityId] as String?,
      communityName: data[CommunityInboxFields.communityName] as String?,
      communityIds: _asStringList(data[CommunityInboxFields.communityIds]),
      title: data[CommunityInboxFields.title] as String?,
      body: data[CommunityInboxFields.body] as String?,
      senderId: data[CommunityInboxFields.senderId] as String?,
      senderName: data[CommunityInboxFields.senderName] as String?,
      role: data[CommunityInboxFields.role] as String?,
      previousRole: data[CommunityInboxFields.previousRole] as String?,
      targetUserId: data[CommunityInboxFields.targetUserId] as String?,
      read: data[CommunityInboxFields.read] == true,
      createdAt: _asDateTime(data[CommunityInboxFields.createdAt]),
    );
  }
}
