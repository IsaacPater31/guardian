import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:guardian/views/login_view.dart';
import 'package:guardian/views/main_app/main_view.dart';
import 'package:guardian/views/main_app/join_community_view.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/services/deep_link_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _hasCheckedPendingToken = false;

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
          
          // Verificar si hay un token de invitación pendiente (solo una vez)
          if (!_hasCheckedPendingToken) {
            _hasCheckedPendingToken = true;
            _checkPendingInviteToken();
          }
          
          return const MainView();
        }
        // Si no hay usuario logueado
        _hasCheckedPendingToken = false; // Reset para el próximo login
        return const LoginView();
      },
    );
  }
  
  /// Verifica si hay un token de invitación pendiente y navega a unirse
  Future<void> _checkPendingInviteToken() async {
    try {
      final deepLinkService = DeepLinkService();
      final pendingToken = await deepLinkService.consumePendingToken();
      
      if (pendingToken != null && mounted) {
        // Esperar un momento para que la navegación principal se complete
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => JoinCommunityView(initialToken: pendingToken),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error verificando token pendiente: $e');
    }
  }
}
