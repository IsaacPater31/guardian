/// Shared kernel (contracts, pure domain, mappers).
///
/// Prefer importing specific files; this barrel is for discovery.
library;

export 'package:guardian/shared/config/app_constants.dart';
export 'package:guardian/shared/data/mappers/alert_inbox_mapper.dart';
export 'package:guardian/shared/data/mappers/alert_mapper.dart';
export 'package:guardian/shared/data/mappers/community_inbox_mapper.dart';
export 'package:guardian/shared/data/mappers/community_mapper.dart';
export 'package:guardian/shared/data/mappers/member_added_welcome_mapper.dart';
export 'package:guardian/shared/data/mappers/membership_mapper.dart';
export 'package:guardian/shared/domain/alert_type_normalize.dart';
export 'package:guardian/shared/domain/community_inbox_item.dart';
export 'package:guardian/shared/domain/community_visibility.dart';
export 'package:guardian/shared/domain/member_added_welcome_signal.dart';
