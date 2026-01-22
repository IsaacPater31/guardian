import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:guardian/views/auth/auth_gate.dart';
import 'package:guardian/services/localization_service.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
  
  // Aquí puedes procesar la notificación en segundo plano
  if (message.data.containsKey('alertId')) {
    print('Background alert received: ${message.data['alertId']}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Configurar el handler para mensajes en segundo plano
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Inicializar entidades por defecto (solo se crean si no existen)
  // Esto es idempotente - seguro ejecutarlo múltiples veces
  // Optimizado para plan gratuito: solo hace writes si es necesario
  try {
    final created = await CommunityService().initializeEntityCommunities();
    if (created) {
      print('✅ Entidades inicializadas (nuevas creadas)');
    } else {
      print('ℹ️ Entidades ya existían');
    }
  } catch (e) {
    print('❌ Error inicializando entidades: $e');
    // No bloquear inicio de app si falla
  }

  //await FirebaseAuth.instance.signOut();  

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LocalizationService()..initialize(),
      child: Consumer<LocalizationService>(
        builder: (context, localizationService, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Guardian',
            locale: localizationService.currentLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(
              useMaterial3: false,
              fontFamily: 'Inter',
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
              scaffoldBackgroundColor: const Color(0xFFF3F4F6),
              textTheme: const TextTheme(
                headlineLarge: TextStyle(fontWeight: FontWeight.bold),
                bodyMedium: TextStyle(fontWeight: FontWeight.w400),
              ),
            ),
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}
