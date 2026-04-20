import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../models/alert_model.dart';
import 'user_service.dart';
import 'community_service.dart';

/// Data-access layer for alert documents in Firestore.
///
/// Keeps a short-lived cache of the user's community IDs to avoid redundant
/// Firestore reads on every stream update.
class AlertRepository {
  static final AlertRepository _instance = AlertRepository._internal();
  factory AlertRepository() => _instance;
  AlertRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();
  final CommunityService _communityService = CommunityService();

  List<String>? _cachedUserCommunityIds;
  Set<String>? _cachedEntityCommunityIds;
  Map<String, String>? _cachedUserRolesByCommunityId;
  DateTime? _cacheTimestamp;

  // ─── Write operations ────────────────────────────────────────────────────

  /// Persists [alert] and returns the new document ID.
  Future<String> saveAlert(AlertModel alert) async {
    try {
      final ref = await _firestore
          .collection(FirestoreCollections.alerts)
          .add(alert.toFirestore());
      return ref.id;
    } catch (e) {
      AppLogger.e('AlertRepository.saveAlert', e);
      rethrow;
    }
  }

  /// Applies a partial [data] update to the alert identified by [alertId].
  Future<void> updateAlert(String alertId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(FirestoreCollections.alerts)
          .doc(alertId)
          .update(data);
    } catch (e) {
      AppLogger.e('AlertRepository.updateAlert', e);
      rethrow;
    }
  }

  /// Records the current user as a viewer of [alertId].
  ///
  /// Uses a transaction to safely increment [viewedCount] without race
  /// conditions.
  Future<void> markAlertAsViewed(String alertId) async {
    try {
      final currentUser = _userService.currentUser;
      if (currentUser == null) return;

      final alertRef = _firestore
          .collection(FirestoreCollections.alerts)
          .doc(alertId);

      await _firestore.runTransaction((tx) async {
        final alertDoc = await tx.get(alertRef);
        if (!alertDoc.exists) return;

        final viewedBy = List<String>.from(alertDoc.data()?[AlertFields.viewedBy] ?? []);
        final viewedCount = alertDoc.data()?[AlertFields.viewedCount] ?? 0;

        final ownerId = alertDoc.data()?[AlertFields.userId] as String?;
        final ownerEmail = alertDoc.data()?[AlertFields.userEmail] as String?;
        if (_userService.isUserOwnerOfAlert(ownerId, ownerEmail)) {
          return;
        }

        if (!viewedBy.contains(currentUser.uid)) {
          viewedBy.add(currentUser.uid);
          tx.update(alertRef, {
            AlertFields.viewedBy: viewedBy,
            AlertFields.viewedCount: viewedCount + 1,
          });
        }
      });
    } catch (e) {
      AppLogger.e('AlertRepository.markAlertAsViewed', e);
      rethrow;
    }
  }

  /// Reports [alertId] for inappropriate content.
  ///
  /// A user may only report the same alert once. Throws if not authenticated,
  /// the alert does not exist, or the user has already reported it.
  Future<void> reportAlert(String alertId) async {
    final currentUser = _userService.currentUser;
    if (currentUser == null) throw Exception('Usuario no autenticado');

    final alertRef = _firestore
        .collection(FirestoreCollections.alerts)
        .doc(alertId);

    await _firestore.runTransaction((tx) async {
      final alertDoc = await tx.get(alertRef);
      if (!alertDoc.exists) throw Exception('Alerta no encontrada');

      final data = alertDoc.data() ?? {};
      final reportedBy = List<String>.from(data[AlertFields.reportedBy] ?? []);
      final reportsCount = (data[AlertFields.reportsCount] as int?) ?? 0;

      if (reportedBy.contains(currentUser.uid)) {
        throw Exception('Ya has reportado esta alerta');
      }

      reportedBy.add(currentUser.uid);
      tx.update(alertRef, {
        AlertFields.reportedBy: reportedBy,
        AlertFields.reportsCount: reportsCount + 1,
      });
    });
  }

  /// Updates the attended/pending status of [alertId].
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

  // ─── Community ID cache ───────────────────────────────────────────────────

  Future<_UserCommunityAccess> _getUserCommunityAccess() async {
    if (_cachedUserCommunityIds != null &&
        _cachedEntityCommunityIds != null &&
        _cachedUserRolesByCommunityId != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < AppDurations.communityIdCache) {
      return _UserCommunityAccess(
        communityIds: _cachedUserCommunityIds!,
        entityCommunityIds: _cachedEntityCommunityIds!,
        rolesByCommunityId: _cachedUserRolesByCommunityId!,
      );
    }

    try {
      final uid = _userService.currentUser?.uid;
      if (uid == null) {
        return const _UserCommunityAccess(
          communityIds: [],
          entityCommunityIds: <String>{},
          rolesByCommunityId: <String, String>{},
        );
      }

      final communities = await _communityService.getMyCommunities();
      _cachedUserCommunityIds = communities.map((c) => c['id'] as String).toList();
      _cachedEntityCommunityIds = communities
          .where((c) => (c[CommunityFields.isEntity] as bool? ?? false))
          .map((c) => c['id'] as String)
          .toSet();

      final memberships = await _firestore
          .collection(FirestoreCollections.communityMembers)
          .where(MemberFields.userId, isEqualTo: uid)
          .get();
      _cachedUserRolesByCommunityId = {
        for (final doc in memberships.docs)
          (doc.data()[MemberFields.communityId] as String):
              (doc.data()[MemberFields.role] as String? ?? MemberFields.roleMember),
      };

      _cacheTimestamp = DateTime.now();
      return _UserCommunityAccess(
        communityIds: _cachedUserCommunityIds!,
        entityCommunityIds: _cachedEntityCommunityIds!,
        rolesByCommunityId: _cachedUserRolesByCommunityId!,
      );
    } catch (e) {
      AppLogger.e('AlertRepository._getUserCommunityAccess', e);
      return _UserCommunityAccess(
        communityIds: _cachedUserCommunityIds ?? const [],
        entityCommunityIds: _cachedEntityCommunityIds ?? const {},
        rolesByCommunityId: _cachedUserRolesByCommunityId ?? const {},
      );
    }
  }

  /// Clears the community-ID cache, forcing a fresh fetch on the next query.
  void invalidateCommunityCache() {
    _cachedUserCommunityIds = null;
    _cachedEntityCommunityIds = null;
    _cachedUserRolesByCommunityId = null;
    _cacheTimestamp = null;
  }

  // ─── Read: recent alerts (feed) ───────────────────────────────────────────

  /// Returns alerts from the last [AppDurations.alertFeedWindow].
  Future<List<AlertModel>> getRecentAlerts() async {
    try {
      final since = DateTime.now().subtract(AppDurations.alertFeedWindow);

      final snapshot = await _firestore
          .collection(FirestoreCollections.alerts)
          .where(AlertFields.timestamp, isGreaterThan: Timestamp.fromDate(since))
          .orderBy(AlertFields.timestamp, descending: true)
          .limit(AppFirestoreLimits.recentAlerts)
          .get();

      return _filterByPermissionsAndCommunity(
        snapshot.docs.map(AlertModel.fromFirestore).toList(),
        await _getUserCommunityAccess(),
      );
    } catch (e) {
      AppLogger.e('AlertRepository.getRecentAlerts', e);
      return [];
    }
  }

  /// Stream of alerts created by the current user (newest first, capped).
  ///
  /// Requires a Firestore composite index on `alerts`: `userId` + `timestamp`.
  Stream<List<AlertModel>> getMyAlertsStream() {
    final uid = _userService.currentUserId;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.userId, isEqualTo: uid)
        .orderBy(AlertFields.timestamp, descending: true)
        .limit(AppFirestoreLimits.myAlerts)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AlertModel.fromFirestore).toList());
  }

  /// One-shot fetch of [getMyAlertsStream] shape (same cap).
  Future<List<AlertModel>> getMyAlerts() async {
    final uid = _userService.currentUserId;
    if (uid == null) return [];

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.alerts)
          .where(AlertFields.userId, isEqualTo: uid)
          .orderBy(AlertFields.timestamp, descending: true)
          .limit(AppFirestoreLimits.myAlerts)
          .get();
      return snapshot.docs.map(AlertModel.fromFirestore).toList();
    } catch (e) {
      AppLogger.e('AlertRepository.getMyAlerts', e);
      return [];
    }
  }

  /// Reactive stream of recent alerts, filtered by user permissions.
  Stream<List<AlertModel>> getRecentAlertsStream() {
    final since = DateTime.now().subtract(AppDurations.alertFeedWindow);

    return _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.timestamp, isGreaterThan: Timestamp.fromDate(since))
        .orderBy(AlertFields.timestamp, descending: true)
        .limit(AppFirestoreLimits.recentAlerts)
        .snapshots()
        .asyncMap((snapshot) async {
      final communityAccess = await _getUserCommunityAccess();
      return _filterByPermissionsAndCommunity(
        snapshot.docs.map(AlertModel.fromFirestore).toList(),
        communityAccess,
      );
    });
  }

  // ─── Read: map alerts ────────────────────────────────────────────────────

  /// Returns alerts with a location from the last [AppDurations.mapAlertsWindow].
  Future<List<AlertModel>> getMapAlerts() async {
    try {
      final since = DateTime.now().subtract(AppDurations.mapAlertsWindow);

      final snapshot = await _firestore
          .collection(FirestoreCollections.alerts)
          .where(AlertFields.timestamp, isGreaterThan: Timestamp.fromDate(since))
          .orderBy(AlertFields.timestamp, descending: true)
          .limit(AppFirestoreLimits.mapAlerts)
          .get();

      final all = snapshot.docs.map(AlertModel.fromFirestore).toList();
      final visible = all.where((a) {
        if (!a.shareLocation || a.location == null) return false;
        return _userService.canUserViewAlert(a.userId, a.userEmail, a.isAnonymous);
      }).toList();
      return _filterByPermissionsAndCommunity(
        visible,
        await _getUserCommunityAccess(),
      );
    } catch (e) {
      AppLogger.e('AlertRepository.getMapAlerts', e);
      return [];
    }
  }

  /// Reactive stream of map alerts.
  Stream<List<AlertModel>> getMapAlertsStream() {
    final since = DateTime.now().subtract(AppDurations.mapAlertsWindow);

    return _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.timestamp, isGreaterThan: Timestamp.fromDate(since))
        .orderBy(AlertFields.timestamp, descending: true)
        .limit(AppFirestoreLimits.mapAlerts)
        .snapshots()
        .asyncMap((snapshot) async {
      final visible = snapshot.docs
          .map(AlertModel.fromFirestore)
          .where((a) =>
              a.shareLocation &&
              a.location != null &&
              _userService.canUserViewAlert(a.userId, a.userEmail, a.isAnonymous))
          .toList();
      return _filterByPermissionsAndCommunity(
        visible,
        await _getUserCommunityAccess(),
      );
    });
  }

  // ─── Read: map alerts with filters ───────────────────────────────────────

  /// Reactive stream of map alerts with server- and client-side filters applied.
  ///
  /// Parameters:
  /// - [selectedTypes] — alert types to include; empty means all.
  /// - [filterStatus] — `'all'` | `'pending'` | `'attended'`.
  /// - [filterDateRange] — `'all'` | `'today'` | `'yesterday'` | `'week'` |
  ///   `'7days'` | `'month'` | `'custom'`.
  /// - [customStart] / [customEnd] — used when [filterDateRange] == `'custom'`.
  Stream<List<AlertModel>> getMapAlertsStreamFiltered({
    List<String> selectedTypes = const [],
    String filterStatus = 'all',
    String filterDateRange = 'all',
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final hasType = selectedTypes.isNotEmpty;
    final hasStatus = filterStatus != 'all';

    DateTime? start;
    DateTime? end;

    if (filterDateRange != 'all') {
      if (filterDateRange == 'custom') {
        start = customStart;
        end = customEnd;
      } else {
        final range = _resolveDateRange(filterDateRange);
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
        q = q.where(AlertFields.timestamp,
            isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      }
      if (end != null) {
        q = q.where(AlertFields.timestamp,
            isLessThanOrEqualTo: Timestamp.fromDate(end));
      }
    } else {
      if (start != null) {
        q = q.where(AlertFields.timestamp,
            isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      }
      if (end != null) {
        q = q.where(AlertFields.timestamp,
            isLessThanOrEqualTo: Timestamp.fromDate(end));
      }
    }

    q = q.orderBy(AlertFields.timestamp, descending: true);
    q = q.limit(AppFirestoreLimits.mapAlerts);

    return q.snapshots().asyncMap((snapshot) async {
      var alerts = snapshot.docs.map(AlertModel.fromFirestore).toList();

      alerts = alerts
          .where((a) =>
              a.shareLocation &&
              a.location != null &&
              _userService.canUserViewAlert(a.userId, a.userEmail, a.isAnonymous))
          .toList();

      if (hasType && selectedTypes.length > 1) {
        alerts = alerts.where((a) => selectedTypes.contains(a.alertType)).toList();
      }

      if (hasStatus) {
        alerts = alerts.where((a) {
          if (filterStatus == 'attended') return a.alertStatus == 'attended';
          return a.alertStatus != 'attended';
        }).toList();
      }

      return _filterByPermissionsAndCommunity(
        alerts,
        await _getUserCommunityAccess(),
      );
    });
  }

  // ─── Read: community-scoped alerts ───────────────────────────────────────

  /// Returns the 50 most recent alerts for [communityId].
  Future<List<AlertModel>> getCommunityAlerts(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.alerts)
          .where(AlertFields.communityIds, arrayContains: communityId)
          .get();

      final filtered = snapshot.docs
          .map(AlertModel.fromFirestore)
          .where((a) => _userService.canUserViewAlert(a.userId, a.userEmail, a.isAnonymous))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final access = await _getUserCommunityAccess();
      return _filterByPermissionsAndCommunity(filtered, access).take(50).toList();
    } catch (e) {
      AppLogger.e('AlertRepository.getCommunityAlerts', e);
      return [];
    }
  }

  /// Reactive stream of the 50 most recent alerts for [communityId].
  Stream<List<AlertModel>> getCommunityAlertsStream(String communityId) {
    return _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.communityIds, arrayContains: communityId)
        .snapshots()
        .asyncMap((snapshot) async {
      final filtered = snapshot.docs
          .map(AlertModel.fromFirestore)
          .where((a) => _userService.canUserViewAlert(a.userId, a.userEmail, a.isAnonymous))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final access = await _getUserCommunityAccess();
      return _filterByPermissionsAndCommunity(filtered, access).take(50).toList();
    });
  }

  /// Reactive stream of alerts sent by [uid] in [communityId].
  Stream<List<AlertModel>> getOwnAlertsStream(String communityId, String uid) {
    return _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.communityIds, arrayContains: communityId)
        .where(AlertFields.userId, isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(AlertModel.fromFirestore)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  /// Reactive stream of alerts sent by other users in [communityId].
  Stream<List<AlertModel>> getOthersAlertsStream(String communityId, String uid) {
    return _firestore
        .collection(FirestoreCollections.alerts)
        .where(AlertFields.communityIds, arrayContains: communityId)
        .where(AlertFields.userId, isNotEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(AlertModel.fromFirestore)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  // ─── Statistics ───────────────────────────────────────────────────────────

  /// Returns a map of `alertType → count` for recent alerts.
  Future<Map<String, int>> getAlertStatistics() async {
    try {
      final alerts = await getRecentAlerts();
      final stats = <String, int>{};
      for (final alert in alerts) {
        stats[alert.alertType] = (stats[alert.alertType] ?? 0) + 1;
      }
      return stats;
    } catch (e) {
      AppLogger.e('AlertRepository.getAlertStatistics', e);
      return {};
    }
  }

  /// Returns a map of `alertType → total views` for recent alerts.
  Future<Map<String, int>> getViewStatistics() async {
    try {
      final alerts = await getRecentAlerts();
      final stats = <String, int>{};
      for (final alert in alerts) {
        stats[alert.alertType] = (stats[alert.alertType] ?? 0) + alert.viewedCount;
      }
      return stats;
    } catch (e) {
      AppLogger.e('AlertRepository.getViewStatistics', e);
      return {};
    }
  }

  /// Returns unread alert counts grouped by community ID.
  Future<Map<String, int>> getUnreadCountByCommunity() async {
    try {
      final alerts = await getRecentAlerts();
      final uid = _userService.currentUser?.uid;
      if (uid == null) return {};

      final counts = <String, int>{};
      for (final alert in alerts) {
        if (alert.communityIds.isEmpty) continue;
        if (_userService.isUserOwnerOfAlert(alert.userId, alert.userEmail)) {
          continue;
        }
        if (!alert.viewedBy.contains(uid)) {
          for (final cid in alert.communityIds) {
            counts[cid] = (counts[cid] ?? 0) + 1;
          }
        }
      }
      return counts;
    } catch (e) {
      AppLogger.e('AlertRepository.getUnreadCountByCommunity', e);
      return {};
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  List<AlertModel> _filterByPermissionsAndCommunity(
    List<AlertModel> alerts,
    _UserCommunityAccess access,
  ) {
    final uid = _userService.currentUser?.uid;
    final membershipSet = access.communityIds.toSet();

    return alerts.where((alert) {
      if (!_userService.canUserViewAlert(alert.userId, alert.userEmail, alert.isAnonymous)) {
        return false;
      }
      // Show alerts with no community restriction (public/legacy).
      if (alert.communityIds.isEmpty) return true;

      for (final communityId in alert.communityIds) {
        if (!membershipSet.contains(communityId)) continue;

        final isEntity = access.entityCommunityIds.contains(communityId);
        if (!isEntity) return true;

        final role = access.rolesByCommunityId[communityId] ?? MemberFields.roleMember;
        if (role == MemberFields.roleOfficial || role == MemberFields.roleAdmin) {
          return true;
        }
        if (uid != null && alert.userId == uid) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  /// Resolves a named date-range preset to a `(start, end?)` pair.
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

class _UserCommunityAccess {
  final List<String> communityIds;
  final Set<String> entityCommunityIds;
  final Map<String, String> rolesByCommunityId;

  const _UserCommunityAccess({
    required this.communityIds,
    required this.entityCommunityIds,
    required this.rolesByCommunityId,
  });
}
