import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:guardian/core/app_constants.dart';
import 'package:guardian/core/app_logger.dart';
import 'package:guardian/views/auth/auth_gate.dart';
import 'package:guardian/views/main_app/join_community_view.dart';
import 'package:guardian/services/localization_service.dart';
import 'package:guardian/services/deep_link_service.dart';
import 'package:guardian/services/native_background_service.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

/// Global navigator key used by [DeepLinkService] to push routes from outside
/// the widget tree.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// FCM no entrega alertas ni mensajes (lo hace el servicio nativo Kotlin).
/// Se mantiene el handler para compatibilidad con Firebase Messaging en Android.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.d('FCM background (unused for delivery): ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

class _GuardianAppState extends State<GuardianApp> with WidgetsBindingObserver {
  final DeepLinkService _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncForegroundState();
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
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkService.onInviteTokenReceived = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncForegroundState(state);
  }

  void _syncForegroundState([AppLifecycleState? state]) {
    final lifecycle = state ?? WidgetsBinding.instance.lifecycleState;
    final inForeground = lifecycle == AppLifecycleState.resumed;
    NativeBackgroundService.setAppForeground(inForeground);
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
