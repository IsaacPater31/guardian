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

  /// Per-user alert inbox (fan-out from alert creation).
  static const String alertInbox = 'alert_inbox';
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
  /// Audio corto (p. ej. AAC) codificado en base64; opcional.
  static const String audioBase64 = 'audio_base64';
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
  static const String createdAt = 'created_at';
  static const String iconCodePoint = 'icon_code_point';
  static const String iconColor = 'icon_color';
  /// Color del botón principal de reportes para entidades.
  static const String reportButtonColor = 'report_button_color';
  /// Tipos de alerta (`alertType`) que esta entidad acepta como reportes.
  static const String reportAlertTypes = 'report_alert_types';
  /// Marca comunidades creadas por defecto al primer acceso (p. ej. `hogar`).
  static const String defaultSlug = 'default_slug';
}

abstract final class MemberFields {
  static const String userId = 'user_id';
  static const String communityId = 'community_id';
  static const String role = 'role';
  static const String joinedAt = 'joined_at';

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleMember = 'member';

  /// Funcionario de una entidad (comunidad `is_entity`).
  /// Es el único rol staff que recibe reportes de terceros en entidades.
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

/// Fan-out inbox at `users/{uid}/alert_inbox/{alertId}`.
abstract final class AlertInboxFields {
  static const String alertId = 'alert_id';
  static const String communityIds = 'community_ids';
  static const String alertType = 'alert_type';
  static const String flowType = 'type';
  static const String description = 'description';
  static const String isAnonymous = 'is_anonymous';
  static const String shareLocation = 'share_location';
  static const String senderId = 'sender_id';
  static const String senderName = 'sender_name';
  static const String read = 'read';
  static const String createdAt = 'created_at';
  static const String alertStatus = 'alert_status';
}

/// Soft inbox at `users/{uid}/community_messages/{id}` (messages + membership).
abstract final class CommunityInboxFields {
  static const String kind = 'kind';
  static const String messageId = 'message_id';
  static const String communityId = 'community_id';
  static const String communityName = 'community_name';
  static const String communityIds = 'community_ids';
  static const String title = 'title';
  static const String body = 'body';
  static const String senderId = 'sender_id';
  static const String senderName = 'sender_name';
  static const String role = 'role';
  static const String previousRole = 'previous_role';
  static const String targetUserId = 'target_user_id';
  static const String read = 'read';
  static const String createdAt = 'created_at';

  static const String kindMessage = 'community_message';
  static const String kindMemberAdded = 'member_added';
  static const String kindMemberRemoved = 'member_removed';
  static const String kindRoleChanged = 'role_changed';
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
  /// How long community-ID cache stays valid in [AlertService].
  static const Duration communityIdCache = Duration(minutes: 5);

  /// Window for the recent-alerts feed (home & community views).
  static const Duration alertFeedWindow = Duration(hours: 24);

  /// Window for alerts shown on the map.
  static const Duration mapAlertsWindow = Duration(days: 7);

  /// How long an invite token is valid after creation.
  static const Duration inviteExpiry = Duration(hours: 12);

  /// Delay before retrying missing permissions on first launch.
  static const Duration permissionRetryDelay = Duration(seconds: 3);

  /// How long vibration + UI pulse run when a new pending alert arrives.
  /// Keep in sync with Android `GuardianNativeConfig.Durations.ACTIVE_ALERT_FEEDBACK_MS`
  /// and web `ACTIVE_ALERT_FEEDBACK_MS`.
  static const Duration activeAlertFeedback = Duration(seconds: 10);
}

/// Geographic thresholds for location-based UI.
abstract final class AppGeoLimits {
  /// Home "Alertas cercanas recientes": max distance from the user's position.
  static const double nearbyAlertsMaxDistanceMeters = 500;
}

/// Caps on Firestore query size (one read per document returned).
abstract final class AppFirestoreLimits {
  /// Recent-alerts window (home, streams, stats): newest documents only.
  static const int recentAlerts = 100;

  /// Map queries: max documents before location / permission client filters.
  /// Aligns with `QUERY_CONFIG.mapFetchLimit` on the web app.
  static const int mapAlerts = 1000;

  /// "Mis alertas": newest documents for the current user (`userId` query).
  static const int myAlerts = 200;
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
