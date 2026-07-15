import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:guardian/features/alerts/domain/alert_model.dart';

/// Maps alert Firestore documents ↔ [AlertModel].
///
/// Serialization currently delegates to [AlertModel]; call sites should use
/// this mapper so persistence mapping stays out of presentation/application.
class AlertMapper {
  AlertMapper._();

  static AlertModel fromDoc(DocumentSnapshot doc) => AlertModel.fromFirestore(doc);

  static Map<String, dynamic> toFirestore(AlertModel alert) => alert.toFirestore();
}
