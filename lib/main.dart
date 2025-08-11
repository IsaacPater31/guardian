import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
//import 'package:firebase_auth/firebase_auth.dart';        // <-- agrega esto
import 'package:guardian/views/auth/auth_gate.dart';
import 'package:guardian/services/notification_service.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🚨 Background message received: ${message.messageId}');
  
  // Procesar notificación de emergencia en segundo plano
  if (message.data.containsKey('alertId')) {
    final alertId = message.data['alertId'];
    final alertType = message.data['alertType'] ?? 'EMERGENCY';
    
    print('🚨 Emergency alert received in background: $alertType (ID: $alertId)');
    
    // Aquí puedes agregar lógica adicional para notificaciones críticas
    // Por ejemplo, vibrar el dispositivo, mostrar notificación local, etc.
    
    // Mostrar notificación local para asegurar que el usuario la vea
    if (message.notification != null) {
      print('📱 Showing local notification for emergency alert');
      // La notificación se mostrará automáticamente por FCM
    }
  }
  
  // Log detallado para debugging
  print('📋 Background message data: ${message.data}');
  print('📋 Background message notification: ${message.notification?.title} - ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Configurar el handler para mensajes en segundo plano
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  //await FirebaseAuth.instance.signOut();  

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Guardian',
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
      home: const AuthGate(), // <--- ¡Así está bien!
    );
  }
}
