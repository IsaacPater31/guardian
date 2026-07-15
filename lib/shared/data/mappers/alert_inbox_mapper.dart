import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:guardian/features/alerts/domain/alert_model.dart';
import 'package:guardian/shared/config/app_constants.dart';

/// Maps alert domain data ↔ `users/{uid}/alert_inbox` document payloads.
class AlertInboxMapper {
  AlertInboxMapper._();

  /// Shared fields written to each recipient's inbox doc (without per-user community ids).
  static Map<String, dynamic> toFirestorePayload({
    required String alertId,
    required AlertModel alert,
  }) {
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
