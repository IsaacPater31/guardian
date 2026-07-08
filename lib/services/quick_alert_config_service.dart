import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../core/community_visibility.dart';
import '../repositories/community_repository.dart';

/// Manages the set of communities that receive a Quick Alert.
///
/// Defaults to an empty selection until the user configures destinations.
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

      _cachedDestinations = [];
      return [];
    } catch (e) {
      AppLogger.e('QuickAlertConfigService.getQuickAlertDestinations', e);
      return [];
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
      return visibleUserCommunities(
        await _communities.fetchUserCommunities(userId),
      );
    } catch (e) {
      AppLogger.e('QuickAlertConfigService.getAvailableDestinations', e);
      return [];
    }
  }

  void invalidateCache() => _cachedDestinations = null;
}
