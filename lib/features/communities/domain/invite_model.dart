import 'package:cloud_firestore/cloud_firestore.dart';

class InviteModel {
  final String token; // PK
  final String communityId;
  final DateTime expiresAt; // 12 horas desde creación

  InviteModel({
    required this.token,
    required this.communityId,
    required this.expiresAt,
  });

  factory InviteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InviteModel(
      token: doc.id,
      communityId: data['community_id'] ?? '',
      expiresAt: (data['expires_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'community_id': communityId,
      'expires_at': Timestamp.fromDate(expiresAt),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

