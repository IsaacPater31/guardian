import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../repositories/community_repository.dart';

/// Manages the set of communities that receive a Quick Alert.
///
/// Defaults to all entity communities. The user can override this via the
/// settings screen; the selection is persisted in [SharedPreferences].
class QuickAlertConfigService {
  static final QuickAlertConfigService _instance = QuickAlertConfigService._internal();
  factory QuickAlertConfigService() => _instance;
  QuickAlertConfigService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CommunityRepository _communities = CommunityRepository();

  List<String>? _cachedDestinations;

  Future<List<String>> getQuickAlertDestinations() async {
    if (_cachedDestinations != null) return _cachedDestinations!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(PrefKeys.quickAlertDestinations);

      if (savedIds != null && savedIds.isNotEmpty) {
        final validIds = await _communities.validateCommunityIds(savedIds);
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

  Future<bool> updateQuickAlertDestinations(List<String> communityIds) async {
    try {
      final validIds = await _communities.validateCommunityIds(communityIds);
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

  Future<List<Map<String, dynamic>>> getAvailableDestinations() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      return _communities.fetchUserCommunities(userId);
    } catch (e) {
      AppLogger.e('QuickAlertConfigService.getAvailableDestinations', e);
      return [];
    }
  }

  void invalidateCache() => _cachedDestinations = null;

  Future<List<String>> _getDefaultEntityIds() async {
    try {
      final snap = await _communities.fetchAllEntityCommunities();
      return snap.docs.map((d) => d.id).toList();
    } catch (e) {
      AppLogger.e('QuickAlertConfigService._getDefaultEntityIds', e);
      return [];
    }
  }
}
