/// Central repository for all application-wide constants.
///
/// Grouping constants here ensures that any change to a string
/// (collection name, SharedPreferences key, duration, etc.) is made in a
/// single place and automatically reflected everywhere it is used.
library;

// ─── Firestore collection names ─────────────────────────────────────────────

/// Top-level constants for every Firestore collection used by the app.
/// Prevents typo-driven bugs and makes collection renames trivially easy.
abstract final class FirestoreCollections {
  static const String alerts = 'alerts';
  static const String communities = 'communities';
  static const String communityMembers = 'community_members';
  static const String invites = 'invites';
  static const String memberReports = 'member_reports';
  static const String users = 'users';

  /// Ephemeral docs so a user knows they were added to a community (client shows + deletes).
  static const String memberAddedSignals = 'member_added_signals';
}

// ─── Firestore field names (shared across collections) ───────────────────────

abstract final class AlertFields {
  static const String type = 'type';
  static const String alertType = 'alertType';
  static const String description = 'description';
  static const String timestamp = 'timestamp';
  static const String isAnonymous = 'isAnonymous';
  static const String shareLocation = 'shareLocation';
  static const String location = 'location';
  static const String userId = 'userId';
  static const String userEmail = 'userEmail';
  static const String userName = 'userName';
  static const String imageBase64 = 'imageBase64';
  static const String viewedCount = 'viewedCount';
  static const String viewedBy = 'viewedBy';
  static const String communityId  = 'community_id';   // legacy (read-only, backward compat)
  static const String communityIds = 'community_ids';  // new array field
  static const String alertStatus = 'alert_status';
  static const String forwardsCount = 'forwards_count';
  static const String reportsCount = 'reports_count';
  static const String reportedBy = 'reported_by';
}

abstract final class CommunityFields {
  static const String name = 'name';
  static const String description = 'description';
  static const String isEntity = 'is_entity';
  static const String createdBy = 'created_by';
  static const String allowForwardToEntities = 'allow_forward_to_entities';
  static const String createdAt = 'created_at';
  static const String iconCodePoint = 'icon_code_point';
  static const String iconColor = 'icon_color';
}

abstract final class MemberFields {
  static const String userId = 'user_id';
  static const String communityId = 'community_id';
  static const String role = 'role';
  static const String joinedAt = 'joined_at';

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleMember = 'member';
  static const String roleOfficial = 'official';
}

abstract final class InviteFields {
  static const String communityId = 'community_id';
  static const String expiresAt = 'expires_at';
}

abstract final class MemberAddedSignalFields {
  static const String targetUserId = 'target_user_id';
  static const String communityId = 'community_id';
  static const String communityName = 'community_name';
  static const String createdAt = 'created_at';
}

abstract final class ReportFields {
  static const String communityId = 'community_id';
  static const String reportedUserId = 'reported_user_id';
  static const String reportedByUserId = 'reported_by_user_id';
  static const String reason = 'reason';
  static const String createdAt = 'created_at';
  static const String status = 'status';

  static const String statusPending = 'pending';
  static const String statusDismissed = 'dismissed';
}

// ─── SharedPreferences keys ──────────────────────────────────────────────────

abstract final class PrefKeys {
  static const String quickAlertDestinations = 'quick_alert_destinations';

  /// Prefix — append alertType to get the full key.
  /// e.g. '$swipeAlertPrefix$alertType'
  static const String swipeAlertPrefix = 'swipe_alert_communities_';

  static const String selectedLanguage = 'selected_language';
}

// ─── Durations ───────────────────────────────────────────────────────────────

abstract final class AppDurations {
  /// How long community-ID cache stays valid in [AlertRepository].
  static const Duration communityIdCache = Duration(minutes: 5);

  /// Window for the recent-alerts feed (home & community views).
  static const Duration alertFeedWindow = Duration(hours: 24);

  /// Window for alerts shown on the map.
  static const Duration mapAlertsWindow = Duration(days: 7);

  /// How long an invite token is valid after creation.
  static const Duration inviteExpiry = Duration(hours: 12);

  /// Delay before retrying missing permissions on first launch.
  static const Duration permissionRetryDelay = Duration(seconds: 3);
}

// ─── Deep-link / URL ─────────────────────────────────────────────────────────

abstract final class AppUrls {
  /// Base URL used to build community invite links.
  static const String inviteLinkBase = 'guardian.app/join/';

  /// Named route for the join-community screen.
  static const String joinCommunityRoute = '/join-community';

  /// Deep-link path prefix handled by [onGenerateRoute].
  static const String joinPathPrefix = '/join/';
}

// ─── App / Theme ─────────────────────────────────────────────────────────────

abstract final class AppConfig {
  static const String appTitle = 'Guardian';
  static const String defaultFontFamily = 'Inter';

  /// Background color used for both splash and scaffold.
  static const int scaffoldBgColorValue = 0xFFF3F4F6;

  /// Seed color for [ColorScheme.fromSeed].
  static const int seedColorValue = 0xFF3F51B5; // Indigo
}
