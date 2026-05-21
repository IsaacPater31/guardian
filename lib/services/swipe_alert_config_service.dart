import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/alert_type_normalize.dart';
import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../core/default_official_entities.dart';
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
      var key = '${PrefKeys.swipeAlertPrefix}$alertType';
      var saved = prefs.getStringList(key);

      // Migrar preferencias guardadas con claves antiguas (HOME_HELP, etc.).
      if ((saved == null || saved.isEmpty) &&
          AlertTypeNormalize.canonicalToLegacyPrefKey.containsKey(alertType)) {
        final legacy = AlertTypeNormalize.canonicalToLegacyPrefKey[alertType]!;
        final legacyKey = '${PrefKeys.swipeAlertPrefix}$legacy';
        final legacyList = prefs.getStringList(legacyKey);
        if (legacyList != null && legacyList.isNotEmpty) {
          await prefs.setStringList(key, legacyList);
          await prefs.remove(legacyKey);
          saved = legacyList;
        }
      }

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

  Future<void> initDefaults() async {
    for (final entry in EmergencyTypes.typeMetadata.entries) {
      final typeName = entry.value['type'] as String;
      final keyword = entry.value['defaultCommunityKeyword'] as String?;
      if (keyword == null) continue;

      final existing = await getCommunitiesForType(typeName);
      if (existing != null) continue;

      final communityId =
          DefaultOfficialEntities.keywordToCommunityId[keyword.toUpperCase()];
      if (communityId == null) continue;

      final valid = await _communities.validateCommunityIds([communityId]);
      if (valid.isEmpty) continue;

      await setCommunitiesForType(typeName, valid);
      AppLogger.d('SwipeAlertConfig default for $typeName → $valid');
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
