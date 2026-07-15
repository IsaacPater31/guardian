import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:guardian/features/communities/domain/community_model.dart';

/// Maps community Firestore documents ↔ [CommunityModel].
class CommunityMapper {
  CommunityMapper._();

  static CommunityModel fromDoc(DocumentSnapshot doc) =>
      CommunityModel.fromFirestore(doc);

  static Map<String, dynamic> toFirestore(CommunityModel community) =>
      community.toFirestore();
}
