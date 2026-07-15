/// Enriched membership row for admin UI (name/email resolved from profile).
class CommunityMemberListItem {
  const CommunityMemberListItem({
    required this.memberId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.role,
    required this.joinedAt,
  });

  final String memberId;
  final String userId;
  final String userName;
  final String userEmail;
  final String role;
  final DateTime joinedAt;
}
