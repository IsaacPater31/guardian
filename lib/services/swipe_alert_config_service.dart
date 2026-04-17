import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../core/mixins/community_fetch_mixin.dart';
import '../models/emergency_types.dart';

/// Manages the per-alert-type community configuration for swipe alerts.
///
/// Configuration is persisted in [SharedPreferences] using keys of the form
/// `swipe_alert_communities_<ALERT_TYPE>`.
///
/// Defaults are seeded from [EmergencyTypes.defaultCommunityKeyword] the first
/// time a type is accessed without prior configuration.
class SwipeAlertConfigService with CommunityFetchMixin {
  static final SwipeAlertConfigService _instance =
      SwipeAlertConfigService._internal();
  factory SwipeAlertConfigService() => _instance;
  SwipeAlertConfigService._internal();

  @override
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // In-memory cache to avoid repeated SharedPreferences reads per swipe.
  final Map<String, List<String>?> _cache = {};

  // ─── Getters ─────────────────────────────────────────────────────────────

  /// Returns the configured community IDs for [alertType], or `null` if none
  /// have been set (signals the UI to redirect to settings).
  Future<List<String>?> getCommunitiesForType(String alertType) async {
    if (_cache.containsKey(alertType)) return _cache[alertType];

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('${PrefKeys.swipeAlertPrefix}$alertType');

      if (saved == null || saved.isEmpty) {
        _cache[alertType] = null;
        return null;
      }

      final valid = await validateCommunityIds(saved);
      _cache[alertType] = valid.isEmpty ? null : valid;
      return _cache[alertType];
    } catch (e) {
      AppLogger.e('SwipeAlertConfigService.getCommunitiesForType', e);
      return null;
    }
  }

  // ─── Setters ─────────────────────────────────────────────────────────────

  /// Persists the given [communityIds] for [alertType].
  Future<bool> setCommunitiesForType(
    String alertType,
    List<String> communityIds,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('${PrefKeys.swipeAlertPrefix}$alertType', communityIds);
      _cache[alertType] = communityIds.isEmpty ? null : communityIds;
      AppLogger.d('SwipeAlertConfig [$alertType] → ${communityIds.length} community(ies)');
      return true;
    } catch (e) {
      AppLogger.e('SwipeAlertConfigService.setCommunitiesForType', e);
      return false;
    }
  }

  // ─── Defaults ────────────────────────────────────────────────────────────

  /// Seeds default community associations for alert types that declare a
  /// [defaultCommunityKeyword] in [EmergencyTypes].
  ///
  /// Only runs for types that have no saved configuration. Safe to call
  /// multiple times.
  Future<void> initDefaults(List<Map<String, dynamic>> communities) async {
    for (final entry in EmergencyTypes.types.entries) {
      final typeName = entry.value['type'] as String;
      final keyword = entry.value['defaultCommunityKeyword'] as String?;
      if (keyword == null) continue;

      final existing = await getCommunitiesForType(typeName);
      if (existing != null) continue;

      final matched = communities
          .where((c) {
            final name = (c[CommunityFields.name] as String? ?? '').toUpperCase();
            return name.contains(keyword);
          })
          .map((c) => c['id'] as String)
          .toList();

      if (matched.isNotEmpty) {
        await setCommunitiesForType(typeName, matched);
        AppLogger.d('SwipeAlertConfig default for $typeName → $matched');
      }
    }
  }

  // ─── Available communities ────────────────────────────────────────────────

  /// Returns all communities the current user belongs to (for the config UI).
  Future<List<Map<String, dynamic>>> getAvailableCommunities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      return fetchUserCommunities(userId);
    } catch (e) {
      AppLogger.e('SwipeAlertConfigService.getAvailableCommunities', e);
      return [];
    }
  }

  // ─── Cache ────────────────────────────────────────────────────────────────

  /// Clears the in-memory cache. Call this when the user's community
  /// membership changes.
  void invalidateCache() => _cache.clear();
}
