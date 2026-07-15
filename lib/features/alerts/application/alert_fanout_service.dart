import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/alerts/domain/alert_model.dart';
import 'package:guardian/features/communities/domain/community_model.dart';
import 'package:guardian/features/alerts/data/alert_inbox_repository.dart';
import 'package:guardian/features/communities/data/community_repository.dart';
import 'package:guardian/shared/data/mappers/alert_inbox_mapper.dart';

/// Fan-out de alertas a `users/{uid}/alert_inbox` para notificaciones escalables.
///
/// Orquesta reglas de destinatario (entity → only official); writes go through
/// [AlertInboxRepository]. El servicio nativo Kotlin escucha solo el inbox del
/// usuario logueado (igual que los mensajes de comunidad).
class AlertFanoutService {
  static final AlertFanoutService _instance = AlertFanoutService._internal();
  factory AlertFanoutService() => _instance;
  AlertFanoutService._internal({
    CommunityRepository? communityRepository,
    AlertInboxRepository? alertInboxRepository,
  })  : _communityRepository = communityRepository ?? CommunityRepository(),
        _alertInboxRepository = alertInboxRepository ?? AlertInboxRepository();

  final CommunityRepository _communityRepository;
  final AlertInboxRepository _alertInboxRepository;

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

        final members =
            await _communityRepository.listMembersByCommunity(communityId);

        for (final member in members) {
          final uid = member.userId;
          if (uid.isEmpty) continue;
          if (senderId != null && uid == senderId) continue;
          if (!_shouldNotifyMember(community, member.role)) continue;

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

      final inboxPayload = AlertInboxMapper.toFirestorePayload(
        alertId: alertId,
        alert: alert,
      );

      await _alertInboxRepository.writeFanoutCopies(
        alertId: alertId,
        basePayload: inboxPayload,
        recipientCommunityIds: recipientCommunities,
      );

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
}
