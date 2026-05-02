import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../models/alert_model.dart';

/// Persistence for alert documents only (Firestore queries and writes).
///
/// **Why separate from [AlertService]:** visibility rules, caching, and
/// “who may view what” stay in the service; this class does not import auth or
/// community membership logic.
class AlertRepository {
  static final AlertRepository _instance = AlertRepository._internal();
  factory AlertRepository() => _instance;
  AlertRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Writes ──────────────────────────────────────────────────────────────

  Future<String> saveAlert(AlertModel alert) async {
    try {
      final ref = await _firestore.collection(FirestoreCollections.alerts).add(alert.toFirestore());
      return ref.id;
    } catch (e) {
      AppLogger.e('AlertRepository.saveAlert', e);
      rethrow;
    }
  }

  Future<void> updateAlert(String alertId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(FirestoreCollections.alerts).doc(alertId).update(data);
    } catch (e) {
      AppLogger.e('AlertRepository.updateAlert', e);
      rethrow;
    }
  }

  Future<void> updateAlertStatus(String alertId, String status) async {
    try {
      await _firestore
          .collection(FirestoreCollections.alerts)
          .doc(alertId)
          .update({AlertFields.alertStatus: status});
    } catch (e) {
      AppLogger.e('AlertRepository.updateAlertStatus', e);
      rethrow;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getAlertDocument(String alertId) {
    return _firestore.collection(FirestoreCollections.alerts).doc(alertId).get();
  }

  /// Increments viewed count when [viewerUid] is not already in [viewedBy].
  Future<void> runMarkViewedTransaction(String alertId, String viewerUid) async {
    final alertRef = _firestore.collection(FirestoreCollections.alerts).doc(alertId);
    await _firestore.runTransaction((tx) async {
      final alertDoc = await tx.get(alertRef);
      if (!alertDoc.exists) return;

      final viewedBy = List<String>.from(alertDoc.data()?[AlertFields.viewedBy] ?? []);
      final viewedCount = alertDoc.data()?[AlertFields.viewedCount] ?? 0;

      if (!viewedBy.contains(viewerUid)) {
        viewedBy.add(viewerUid);
        tx.update(alertRef, {
          AlertFields.viewedBy: viewedBy,
          AlertFields.viewedCount: viewedCount + 1,
        });
      }
    });
  }

  /// Appends [reporterUid] to [reportedBy] or throws if already present / missing doc.
  Future<void> runReportTransaction(String alertId, String reporterUid) async {
    final alertRef = _firestore.collection(FirestoreCollections.alerts).doc(alertId);
    await _firestore.runTransaction((tx) async {
      final alertDoc = await tx.get(alertRef);
      if (!alertDoc.exists) throw Exception('Alerta no encontrada');

      final data = alertDoc.data() ?? {};
      final reportedBy = List<String>.from(data[AlertFields.reportedBy] ?? []);
      final reportsCount = (data[AlertFields.reportsCount] as int?) ?? 0;

      if (reportedBy.contains(reporterUid)) {
        throw Exception('Ya has reportado esta alerta');
      }

      reportedBy.add(reporterUid);
      tx.update(alertRef, {
        AlertFields.reportedBy: reportedBy,
        AlertFields.reportsCount: reportsCount + 1,
      });
    });
  }

  /// Creates forwarded alert docs and updates [forwardsCount] on the original.
  Future<int> commitForwardBatch({
    required String originalAlertId,
    required List<AlertModel> forwardedAlerts,
    required int previousForwardsCount,
  }) async {
    final batch = _firestore.batch();
    var successCount = 0;

    for (final forwarded in forwardedAlerts) {
      final ref = _firestore.collection(FirestoreCollections.alerts).doc();
      batch.set(ref, forwarded.toFirestore());
      successCount++;
    }

    batch.update(
      _firestore.collection(FirestoreCollections.alerts).doc(originalAlertId),
      {AlertFields.forwardsCount: previousForwardsCount + successCount},
    );

    await batch.commit();
    return successCount;
  }

  // ─── Reads (unfiltered) ──────────────────────────────────────────────────

  Future<List<AlertModel>> fetchRecentAlertsSince(DateTime since) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.timestamp, isGreaterThan: Timestamp.fromDate(since))
        .orderBy(AlertFields.timestamp, descending: true)
        .limit(AppFirestoreLimits.recentAlerts)
        .get();
    return snapshot.docs.map(AlertModel.fromFirestore).toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecentAlertsSince(DateTime since) {
    return _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.timestamp, isGreaterThan: Timestamp.fromDate(since))
        .orderBy(AlertFields.timestamp, descending: true)
        .limit(AppFirestoreLimits.recentAlerts)
        .snapshots();
  }

  Future<List<AlertModel>> fetchMapAlertsSince(DateTime since) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.timestamp, isGreaterThan: Timestamp.fromDate(since))
        .orderBy(AlertFields.timestamp, descending: true)
        .limit(AppFirestoreLimits.mapAlerts)
        .get();
    return snapshot.docs.map(AlertModel.fromFirestore).toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMapAlertsSince(DateTime since) {
    return _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.timestamp, isGreaterThan: Timestamp.fromDate(since))
        .orderBy(AlertFields.timestamp, descending: true)
        .limit(AppFirestoreLimits.mapAlerts)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMapAlertsFiltered({
    List<String> selectedTypes = const [],
    String filterStatus = 'all',
    String filterDateRange = 'all',
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final hasType = selectedTypes.isNotEmpty;

    DateTime? start;
    DateTime? end;

    if (filterDateRange != 'all') {
      if (filterDateRange == 'custom') {
        start = customStart;
        end = customEnd;
      } else {
        final range = AlertRepository._resolveDateRange(filterDateRange);
        start = range.$1;
        end = range.$2;
      }
    } else {
      start = DateTime.now().subtract(AppDurations.mapAlertsWindow);
    }

    Query<Map<String, dynamic>> q = _firestore.collection(FirestoreCollections.alerts);

    if (hasType && selectedTypes.length == 1) {
      q = q.where(AlertFields.alertType, isEqualTo: selectedTypes.first);
      if (start != null) {
        q = q.where(AlertFields.timestamp, isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      }
      if (end != null) {
        q = q.where(AlertFields.timestamp, isLessThanOrEqualTo: Timestamp.fromDate(end));
      }
    } else {
      if (start != null) {
        q = q.where(AlertFields.timestamp, isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      }
      if (end != null) {
        q = q.where(AlertFields.timestamp, isLessThanOrEqualTo: Timestamp.fromDate(end));
      }
    }

    q = q.orderBy(AlertFields.timestamp, descending: true);
    q = q.limit(AppFirestoreLimits.mapAlerts);

    return q.snapshots();
  }

  Future<List<AlertModel>> fetchCommunityAlerts(String communityId) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.communityIds, arrayContains: communityId)
        .get();
    final filtered = snapshot.docs.map(AlertModel.fromFirestore).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCommunityAlerts(String communityId) {
    return _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.communityIds, arrayContains: communityId)
        .snapshots();
  }

  Stream<List<AlertModel>> watchMyAlerts({String? uid, String? email}) {
    if (uid == null && (email == null || email.isEmpty)) {
      return Stream.value([]);
    }

    QuerySnapshot<Map<String, dynamic>>? byIdSnapshot;
    QuerySnapshot<Map<String, dynamic>>? byEmailSnapshot;

    List<AlertModel> mergeSnapshots() {
      final dedup = <String, AlertModel>{};

      final byIdDocs = byIdSnapshot?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final byEmailDocs =
          byEmailSnapshot?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      for (final doc in [...byIdDocs, ...byEmailDocs]) {
        dedup[doc.id] = AlertModel.fromFirestore(doc);
      }

      final merged = dedup.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return merged.take(AppFirestoreLimits.myAlerts).toList();
    }

    return Stream.multi((controller) {
      final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

      if (uid != null) {
        subs.add(
          _firestore
              .collection(FirestoreCollections.alerts)
              .where(AlertFields.userId, isEqualTo: uid)
              .orderBy(AlertFields.timestamp, descending: true)
              .limit(AppFirestoreLimits.myAlerts)
              .snapshots()
              .listen(
            (snapshot) {
              byIdSnapshot = snapshot;
              controller.add(mergeSnapshots());
            },
            onError: controller.addError,
          ),
        );
      }

      if (email != null && email.isNotEmpty) {
        subs.add(
          _firestore
              .collection(FirestoreCollections.alerts)
              .where(AlertFields.userEmail, isEqualTo: email)
              .orderBy(AlertFields.timestamp, descending: true)
              .limit(AppFirestoreLimits.myAlerts)
              .snapshots()
              .listen(
            (snapshot) {
              byEmailSnapshot = snapshot;
              controller.add(mergeSnapshots());
            },
            onError: controller.addError,
          ),
        );
      }

      controller.onCancel = () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      };
    });
  }

  Future<List<AlertModel>> fetchMyAlerts({String? uid, String? email}) async {
    if (uid == null && (email == null || email.isEmpty)) return [];

    try {
      final byIdFuture = uid == null
          ? Future.value(const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
          : _firestore
              .collection(FirestoreCollections.alerts)
              .where(AlertFields.userId, isEqualTo: uid)
              .orderBy(AlertFields.timestamp, descending: true)
              .limit(AppFirestoreLimits.myAlerts)
              .get()
              .then((snapshot) => snapshot.docs);

      final byEmailFuture = (email == null || email.isEmpty)
          ? Future.value(const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
          : _firestore
              .collection(FirestoreCollections.alerts)
              .where(AlertFields.userEmail, isEqualTo: email)
              .orderBy(AlertFields.timestamp, descending: true)
              .limit(AppFirestoreLimits.myAlerts)
              .get()
              .then((snapshot) => snapshot.docs);

      final results = await Future.wait([byIdFuture, byEmailFuture]);
      final dedup = <String, AlertModel>{};

      for (final doc in results.expand((docs) => docs)) {
        dedup[doc.id] = AlertModel.fromFirestore(doc);
      }

      final alerts = dedup.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return alerts.take(AppFirestoreLimits.myAlerts).toList();
    } catch (e) {
      AppLogger.e('AlertRepository.fetchMyAlerts', e);
      return [];
    }
  }

  Stream<List<AlertModel>> watchOwnAlertsInCommunity(String communityId, String uid) {
    return _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.communityIds, arrayContains: communityId)
        .where(AlertFields.userId, isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(AlertModel.fromFirestore).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  Stream<List<AlertModel>> watchOthersAlertsInCommunity(String communityId, String uid) {
    return _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.communityIds, arrayContains: communityId)
        .where(AlertFields.userId, isNotEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(AlertModel.fromFirestore).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  static (DateTime, DateTime?) _resolveDateRange(String range) {
    final now = DateTime.now();
    switch (range) {
      case 'today':
        return (
          DateTime(now.year, now.month, now.day),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case 'yesterday':
        final y = now.subtract(const Duration(days: 1));
        return (
          DateTime(y.year, y.month, y.day),
          DateTime(y.year, y.month, y.day, 23, 59, 59),
        );
      case 'week':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return (DateTime(monday.year, monday.month, monday.day), null);
      case '7days':
        return (now.subtract(const Duration(days: 6)), null);
      case 'month':
        return (DateTime(now.year, now.month, 1), null);
      default:
        return (now.subtract(AppDurations.mapAlertsWindow), null);
    }
  }
}
