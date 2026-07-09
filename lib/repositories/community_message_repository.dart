import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_constants.dart';

/// Inbox items at `users/{uid}/community_messages` (fan-out from web panel).
class CommunityMessageRepository {
  CommunityMessageRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _inbox(String userId) =>
      _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('community_messages');

  Stream<List<Map<String, dynamic>>> watchInbox(String userId, {int limit = 50}) {
    return _inbox(userId)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            return {
              'id': d.id,
              ...data,
            };
          }).toList(),
        );
  }

  Future<void> markRead(String userId, String inboxDocId) async {
    await _inbox(userId).doc(inboxDocId).update({'read': true});
  }
}
