import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:guardian/views/login_view.dart';
import 'package:guardian/views/main_app/main_view.dart';
import 'package:guardian/services/community_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Si está cargando...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Si hay usuario logueado
        if (snapshot.hasData) {
          // Agregar usuario a entidades si no está ya (idempotente)
          // Se ejecuta en background, no bloquea la UI
          // Usar catchError para manejar errores sin bloquear
          CommunityService().ensureUserInEntities().catchError((error) {
            print('⚠️ Error agregando usuario a entidades en AuthGate: $error');
          });
          return const MainView();
        }
        // Si no hay usuario logueado
        return const LoginView();
      },
    );
  }
}
