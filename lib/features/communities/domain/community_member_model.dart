import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:guardian/shared/config/app_constants.dart';

class CommunityMemberModel {
  final String? id;
  final String userId;
  final String communityId;
  final DateTime joinedAt;
  final String role; // 'admin', 'member' u 'official'

  CommunityMemberModel({
    this.id,
    required this.userId,
    required this.communityId,
    required this.joinedAt,
    this.role = MemberFields.roleMember,
  });

  factory CommunityMemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityMemberModel(
      id: doc.id,
      userId: data[MemberFields.userId] ?? '',
      communityId: data[MemberFields.communityId] ?? '',
      joinedAt: (data[MemberFields.joinedAt] as Timestamp).toDate(),
      role: data[MemberFields.role] ?? MemberFields.roleMember,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      MemberFields.userId: userId,
      MemberFields.communityId: communityId,
      MemberFields.joinedAt: Timestamp.fromDate(joinedAt),
      MemberFields.role: role,
    };
  }

  /// Verifica si es administrador (creador de la comunidad)
  bool get isAdmin => role == MemberFields.roleAdmin;

  /// Verifica si es miembro normal
  bool get isNormalMember => role == MemberFields.roleMember;

  /// Verifica si es funcionario/oficial de una entidad
  bool get isOfficial => role == MemberFields.roleOfficial;
}

