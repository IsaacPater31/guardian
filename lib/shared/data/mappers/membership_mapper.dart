import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:guardian/features/communities/domain/community_member_model.dart';

/// Maps `community_members` documents ↔ [CommunityMemberModel].
class MembershipMapper {
  MembershipMapper._();

  static CommunityMemberModel fromDoc(DocumentSnapshot doc) =>
      CommunityMemberModel.fromFirestore(doc);

  static Map<String, dynamic> toFirestore(CommunityMemberModel member) =>
      member.toFirestore();
}
