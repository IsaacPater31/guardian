import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../models/alert_model.dart';
import '../models/community_model.dart';
import '../repositories/community_repository.dart';

/// Fan-out de alertas a `users/{uid}/alert_inbox` para notificaciones escalables.
///
/// El servicio nativo Kotlin escucha solo el inbox del usuario logueado
/// (igual que los mensajes de comunidad).
class AlertFanoutService {
  static final AlertFanoutService _instance = AlertFanoutService._internal();
  factory AlertFanoutService() => _instance;
  AlertFanoutService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CommunityRepository _communityRepository = CommunityRepository();

  /// Escribe copias del inbox para cada destinatario elegible.
  Future<void> fanoutAlert(String alertId, AlertModel alert) async {
    if (alert.communityIds.isEmpty) {
      AppLogger.d('AlertFanout: sin comunidades, omitiendo fan-out ($alertId)');
      return;
    }

    try {
      final senderId = alert.userId;
      final recipientCommunities = <String, List<String>>{};

      for (final communityId in alert.communityIds) {
        final community = await _communityRepository.getCommunityById(communityId);
        if (community == null) continue;

        final membersSnap =
            await _communityRepository.queryMembersByCommunity(communityId);

        for (final memberDoc in membersSnap.docs) {
          final data = memberDoc.data();
          final uid = data[MemberFields.userId] as String?;
          if (uid == null || uid.isEmpty) continue;
          if (senderId != null && uid == senderId) continue;

          final role =
              data[MemberFields.role] as String? ?? MemberFields.roleMember;
          if (!_shouldNotifyMember(community, role)) continue;

          recipientCommunities.putIfAbsent(uid, () => <String>[]);
          if (!recipientCommunities[uid]!.contains(communityId)) {
            recipientCommunities[uid]!.add(communityId);
          }
        }
      }

      if (recipientCommunities.isEmpty) {
        AppLogger.d('AlertFanout: sin destinatarios para $alertId');
        return;
      }

      final inboxPayload = _buildInboxPayload(alertId, alert);
      final entries = recipientCommunities.entries.toList();

      for (var i = 0; i < entries.length; i += 400) {
        final batch = _firestore.batch();
        final chunk = entries.skip(i).take(400);

        for (final entry in chunk) {
          final inboxRef = _firestore
              .collection(FirestoreCollections.users)
              .doc(entry.key)
              .collection(FirestoreCollections.alertInbox)
              .doc(alertId);
          batch.set(inboxRef, {
            ...inboxPayload,
            AlertInboxFields.communityIds: entry.value,
          });
        }

        await batch.commit();
      }

      AppLogger.d(
        'AlertFanout: $alertId → ${recipientCommunities.length} destinatarios',
      );
    } catch (e) {
      AppLogger.e('AlertFanoutService.fanoutAlert', e);
    }
  }

  bool _shouldNotifyMember(CommunityModel community, String role) {
    if (!community.isEntity) return true;
    return role == MemberFields.roleOfficial;
  }

  Map<String, dynamic> _buildInboxPayload(String alertId, AlertModel alert) {
    return {
      AlertInboxFields.alertId: alertId,
      AlertInboxFields.alertType: alert.alertType,
      AlertInboxFields.flowType: alert.type,
      AlertInboxFields.description: alert.description,
      AlertInboxFields.isAnonymous: alert.isAnonymous,
      AlertInboxFields.shareLocation: alert.shareLocation,
      AlertInboxFields.senderId: alert.userId,
      AlertInboxFields.senderName: alert.userName,
      AlertInboxFields.read: false,
      AlertInboxFields.alertStatus: alert.alertStatus,
      AlertInboxFields.createdAt: Timestamp.fromDate(alert.timestamp),
    };
  }
}
