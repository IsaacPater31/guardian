import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:guardian/core/app_constants.dart';
import 'package:guardian/core/app_logger.dart';
import 'package:guardian/views/auth/auth_gate.dart';
import 'package:guardian/views/main_app/join_community_view.dart';
import 'package:guardian/services/localization_service.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/services/deep_link_service.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

/// Global navigator key used by [DeepLinkService] to push routes from outside
/// the widget tree.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Handles background FCM messages.
///
/// Must be a top-level function annotated with `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.d('Background message received: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    final created = await CommunityService().initializeEntityCommunities();
    AppLogger.d(created ? 'Entities seeded' : 'Entities already exist');
  } catch (e) {
    AppLogger.e('Entity seeding failed (non-fatal)', e);
  }

  try {
    await DeepLinkService().initialize();
    AppLogger.d('Deep link service initialised');
  } catch (e) {
    AppLogger.e('Deep link service init failed (non-fatal)', e);
  }

  runApp(const GuardianApp());
}

class GuardianApp extends StatefulWidget {
  const GuardianApp({super.key});

  @override
  State<GuardianApp> createState() => _GuardianAppState();
}

class _GuardianAppState extends State<GuardianApp> {
  final DeepLinkService _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    _deepLinkService.onInviteTokenReceived = (token) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushNamed(
          AppUrls.joinCommunityRoute,
          arguments: token,
        );
      });
    };
  }

  @override
  void dispose() {
    _deepLinkService.onInviteTokenReceived = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocalizationService()..initialize(),
      child: Consumer<LocalizationService>(
        builder: (context, localizationService, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: AppConfig.appTitle,
            locale: localizationService.currentLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(
              useMaterial3: false,
              fontFamily: AppConfig.defaultFontFamily,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Color(AppConfig.seedColorValue),
              ),
              scaffoldBackgroundColor: const Color(AppConfig.scaffoldBgColorValue),
              textTheme: const TextTheme(
                headlineLarge: TextStyle(fontWeight: FontWeight.bold),
                bodyMedium: TextStyle(fontWeight: FontWeight.w400),
              ),
            ),
            home: const AuthGate(),
            routes: {
              AppUrls.joinCommunityRoute: (context) {
                final token =
                    ModalRoute.of(context)?.settings.arguments as String?;
                return JoinCommunityView(initialToken: token);
              },
            },
            onGenerateRoute: (settings) {
              if (settings.name?.startsWith(AppUrls.joinPathPrefix) ?? false) {
                final token =
                    settings.name!.substring(AppUrls.joinPathPrefix.length);
                return MaterialPageRoute(
                  builder: (_) => JoinCommunityView(initialToken: token),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
