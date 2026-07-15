/// Enriched pending member-report row for admin UI.
class MemberReportListItem {
  const MemberReportListItem({
    required this.reportId,
    required this.reportedUserId,
    required this.reportedUserName,
    required this.reportedByUserId,
    required this.reportedByUserName,
    required this.reason,
    required this.createdAt,
    required this.status,
  });

  final String reportId;
  final String reportedUserId;
  final String reportedUserName;
  final String reportedByUserId;
  final String reportedByUserName;
  final String reason;
  final DateTime createdAt;
  final String status;
}
