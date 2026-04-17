import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../core/mixins/community_fetch_mixin.dart';

/// Manages the set of communities that receive a Quick Alert.
///
/// Defaults to all entity communities. The user can override this via the
/// settings screen; the selection is persisted in [SharedPreferences].
class QuickAlertConfigService with CommunityFetchMixin {
  static final QuickAlertConfigService _instance =
      QuickAlertConfigService._internal();
  factory QuickAlertConfigService() => _instance;
  QuickAlertConfigService._internal();

  @override
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<String>? _cachedDestinations;

  // ─── Destinations ─────────────────────────────────────────────────────────

  /// Returns the community IDs configured to receive quick alerts.
  ///
  /// Falls back to all entity communities if no configuration has been saved.
  Future<List<String>> getQuickAlertDestinations() async {
    if (_cachedDestinations != null) return _cachedDestinations!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(PrefKeys.quickAlertDestinations);

      if (savedIds != null && savedIds.isNotEmpty) {
        final validIds = await validateCommunityIds(savedIds);
        _cachedDestinations = validIds;
        return validIds;
      }

      final defaultEntities = await _getDefaultEntityIds();
      _cachedDestinations = defaultEntities;
      await prefs.setStringList(PrefKeys.quickAlertDestinations, defaultEntities);
      return defaultEntities;
    } catch (e) {
      AppLogger.e('QuickAlertConfigService.getQuickAlertDestinations', e);
      return await _getDefaultEntityIds();
    }
  }

  /// Persists a new set of [communityIds] as the quick-alert destinations.
  Future<bool> updateQuickAlertDestinations(List<String> communityIds) async {
    try {
      final validIds = await validateCommunityIds(communityIds);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(PrefKeys.quickAlertDestinations, validIds);
      _cachedDestinations = validIds;
      AppLogger.d('QuickAlertConfig updated: ${validIds.length} destination(s)');
      return true;
    } catch (e) {
      AppLogger.e('QuickAlertConfigService.updateQuickAlertDestinations', e);
      return false;
    }
  }

  // ─── Available destinations ───────────────────────────────────────────────

  /// Returns all communities the current user belongs to (for the config UI).
  Future<List<Map<String, dynamic>>> getAvailableDestinations() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      return fetchUserCommunities(userId);
    } catch (e) {
      AppLogger.e('QuickAlertConfigService.getAvailableDestinations', e);
      return [];
    }
  }

  // ─── Cache ────────────────────────────────────────────────────────────────

  /// Clears the in-memory cache. Call this when destinations change externally.
  void invalidateCache() => _cachedDestinations = null;

  // ─── Private helpers ──────────────────────────────────────────────────────

  Future<List<String>> _getDefaultEntityIds() async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.communities)
          .where(CommunityFields.isEntity, isEqualTo: true)
          .get();
      return snap.docs.map((d) => d.id).toList();
    } catch (e) {
      AppLogger.e('QuickAlertConfigService._getDefaultEntityIds', e);
      return [];
    }
  }
}
