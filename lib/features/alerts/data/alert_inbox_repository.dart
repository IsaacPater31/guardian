import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/logging/app_logger.dart';

/// Persistence for `users/{uid}/alert_inbox` (alert notification fan-out).
///
/// Keeps batch writes and collection paths out of [AlertFanoutService].
class AlertInboxRepository {
  AlertInboxRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _inbox(String userId) =>
      _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.alertInbox);

  /// Writes one inbox doc per recipient, merging [basePayload] with that user's
  /// [recipientCommunityIds] under [AlertInboxFields.communityIds].
  ///
  /// Batches of at most 400 writes (Firestore limit).
  Future<void> writeFanoutCopies({
    required String alertId,
    required Map<String, dynamic> basePayload,
    required Map<String, List<String>> recipientCommunityIds,
  }) async {
    if (recipientCommunityIds.isEmpty) return;

    try {
      final entries = recipientCommunityIds.entries.toList();
      for (var i = 0; i < entries.length; i += 400) {
        final batch = _firestore.batch();
        final chunk = entries.skip(i).take(400);

        for (final entry in chunk) {
          final inboxRef = _inbox(entry.key).doc(alertId);
          batch.set(inboxRef, {
            ...basePayload,
            AlertInboxFields.communityIds: entry.value,
          });
        }

        await batch.commit();
      }
    } catch (e) {
      AppLogger.e('AlertInboxRepository.writeFanoutCopies', e);
      rethrow;
    }
  }
}
