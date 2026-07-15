import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para reportes de miembros dentro de una comunidad.
/// Colección Firestore: `member_reports`
class MemberReportModel {
  final String? id;
  final String communityId;
  final String reportedUserId;
  final String reportedByUserId;
  final String reason;
  final DateTime createdAt;
  final String status; // 'pending', 'dismissed'

  MemberReportModel({
    this.id,
    required this.communityId,
    required this.reportedUserId,
    required this.reportedByUserId,
    required this.reason,
    required this.createdAt,
    this.status = 'pending',
  });

  factory MemberReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MemberReportModel(
      id: doc.id,
      communityId: data['community_id'] ?? '',
      reportedUserId: data['reported_user_id'] ?? '',
      reportedByUserId: data['reported_by_user_id'] ?? '',
      reason: data['reason'] ?? '',
      createdAt: (data['created_at'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'community_id': communityId,
      'reported_user_id': reportedUserId,
      'reported_by_user_id': reportedByUserId,
      'reason': reason,
      'created_at': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  bool get isPending => status == 'pending';
  bool get isDismissed => status == 'dismissed';
}
