import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/alert_type_normalize.dart';
import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../core/community_visibility.dart';
import '../repositories/community_repository.dart';

/// Manages per-alert-type community configuration (type/subtype flow).
///
/// Configuration is persisted in [SharedPreferences] using keys of the form
/// `swipe_alert_communities_<ALERT_TYPE>`.
class TypedAlertConfigService {
  static final TypedAlertConfigService _instance =
      TypedAlertConfigService._internal();
  factory TypedAlertConfigService() => _instance;
  TypedAlertConfigService._internal();

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
      AppLogger.e('TypedAlertConfigService.getCommunitiesForType', e);
      return null;
    }
  }

  Future<bool> setCommunitiesForType(
    String alertType,
    List<String> communityIds,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        '${PrefKeys.swipeAlertPrefix}$alertType',
        communityIds,
      );
      _cache[alertType] = communityIds.isEmpty ? null : communityIds;
      AppLogger.d(
        'SwipeAlertConfig [$alertType] → ${communityIds.length} community(ies)',
      );
      return true;
    } catch (e) {
      AppLogger.e('TypedAlertConfigService.setCommunitiesForType', e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableCommunities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      return visibleUserCommunities(
        await _communities.fetchUserCommunities(userId),
      );
    } catch (e) {
      AppLogger.e('TypedAlertConfigService.getAvailableCommunities', e);
      return [];
    }
  }

  void invalidateCache() => _cache.clear();
}

@Deprecated('Use TypedAlertConfigService')
typedef SwipeAlertConfigService = TypedAlertConfigService;
