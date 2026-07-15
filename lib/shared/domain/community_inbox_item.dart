import 'package:guardian/shared/config/app_constants.dart';

/// Soft-inbox row at `users/{uid}/community_messages/{id}`.
///
/// Free of Firestore SDK types so presentation never sees `Timestamp`.
class CommunityInboxItem {
  const CommunityInboxItem({
    required this.id,
    this.kind,
    this.messageId,
    this.communityId,
    this.communityName,
    this.communityIds = const [],
    this.title,
    this.body,
    this.senderId,
    this.senderName,
    this.role,
    this.previousRole,
    this.targetUserId,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String? kind;
  final String? messageId;
  final String? communityId;
  final String? communityName;
  final List<String> communityIds;
  final String? title;
  final String? body;
  final String? senderId;
  final String? senderName;
  final String? role;
  final String? previousRole;
  final String? targetUserId;
  final bool read;
  final DateTime? createdAt;

  bool get isUnread => !read;

  bool get isCommunityMessage =>
      kind == CommunityInboxFields.kindMessage || kind == null;

  bool get isMembershipEvent =>
      kind == CommunityInboxFields.kindMemberAdded ||
      kind == CommunityInboxFields.kindMemberRemoved ||
      kind == CommunityInboxFields.kindMemberLeft ||
      kind == CommunityInboxFields.kindRoleChanged;

  CommunityInboxItem copyWith({bool? read}) {
    return CommunityInboxItem(
      id: id,
      kind: kind,
      messageId: messageId,
      communityId: communityId,
      communityName: communityName,
      communityIds: communityIds,
      title: title,
      body: body,
      senderId: senderId,
      senderName: senderName,
      role: role,
      previousRole: previousRole,
      targetUserId: targetUserId,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }
}
