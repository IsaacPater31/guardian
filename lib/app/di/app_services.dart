import 'package:flutter/foundation.dart';
import 'package:guardian/features/alerts/application/alert_service.dart';
import 'package:guardian/features/auth/application/user_service.dart';
import 'package:guardian/features/communities/application/community_service.dart';
import 'package:guardian/features/home_shell/application/deep_link_service.dart';
import 'package:guardian/features/inbox/application/community_message_service.dart';
import 'package:guardian/features/settings/application/localization_service.dart';

/// Lightweight composition root for application services.
///
/// Existing singleton factories (`AlertService()`, `CommunityService()`, …)
/// remain the implementation. New code and bootstrap should resolve through
/// [AppServices.instance] so a single place owns wiring and tests can replace
/// the root later without hunting `FooService()` call sites.
///
/// This intentionally avoids a DI package (KISS): we already have constructor
/// injection on coordinators; this root is the app-level seam.
class AppServices {
  AppServices._();

  static AppServices instance = AppServices._();

  /// Recreates the root (for tests). Production code should not call this.
  @visibleForTesting
  static void reset() {
    instance = AppServices._();
  }

  // Lazy getters delegate to existing factories — same instances as today.
  UserService get user => UserService();
  AlertService get alerts => AlertService();
  CommunityService get communities => CommunityService();
  CommunityMessageService get communityMessages => CommunityMessageService();
  DeepLinkService get deepLinks => DeepLinkService();
  LocalizationService get localization => LocalizationService();
}
