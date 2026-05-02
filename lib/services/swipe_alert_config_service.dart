import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../models/emergency_types.dart';
import '../repositories/community_repository.dart';

/// Manages the per-alert-type community configuration for swipe alerts.
///
/// Configuration is persisted in [SharedPreferences] using keys of the form
/// `swipe_alert_communities_<ALERT_TYPE>`.
///
/// Defaults are seeded from [EmergencyTypes.defaultCommunityKeyword] the first
/// time a type is accessed without prior configuration.
class SwipeAlertConfigService {
  static final SwipeAlertConfigService _instance = SwipeAlertConfigService._internal();
  factory SwipeAlertConfigService() => _instance;
  SwipeAlertConfigService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CommunityRepository _communities = CommunityRepository();

  final Map<String, List<String>?> _cache = {};

  Future<List<String>?> getCommunitiesForType(String alertType) async {
    if (_cache.containsKey(alertType)) return _cache[alertType];

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('${PrefKeys.swipeAlertPrefix}$alertType');

      if (saved == null || saved.isEmpty) {
        _cache[alertType] = null;
        return null;
      }

      final valid = await _communities.validateCommunityIds(saved);
      _cache[alertType] = valid.isEmpty ? null : valid;
      return _cache[alertType];
    } catch (e) {
      AppLogger.e('SwipeAlertConfigService.getCommunitiesForType', e);
      return null;
    }
  }

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

  Future<void> initDefaults(List<Map<String, dynamic>> communities) async {
    for (final entry in EmergencyTypes.typeMetadata.entries) {
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

  Future<List<Map<String, dynamic>>> getAvailableCommunities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      return _communities.fetchUserCommunities(userId);
    } catch (e) {
      AppLogger.e('SwipeAlertConfigService.getAvailableCommunities', e);
      return [];
    }
  }

  void invalidateCache() => _cache.clear();
}
