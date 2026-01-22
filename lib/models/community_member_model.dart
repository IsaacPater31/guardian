import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityMemberModel {
  final String? id;
  final String userId;
  final String communityId;
  final DateTime joinedAt;
  final String role; // 'member' (usuario normal) o 'official' (ente oficial)

  CommunityMemberModel({
    this.id,
    required this.userId,
    required this.communityId,
    required this.joinedAt,
    this.role = 'member', // Por defecto es miembro normal
  });

  factory CommunityMemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityMemberModel(
      id: doc.id,
      userId: data['user_id'] ?? '',
      communityId: data['community_id'] ?? '',
      joinedAt: (data['joined_at'] as Timestamp).toDate(),
      role: data['role'] ?? 'member', // Compatibilidad: si no existe, es 'member'
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'community_id': communityId,
      'joined_at': Timestamp.fromDate(joinedAt),
      'role': role,
    };
  }

  /// Verifica si es miembro oficial (ente)
  bool get isOfficial => role == 'official';
  
  /// Verifica si es miembro normal
  bool get isNormalMember => role == 'member';
}

