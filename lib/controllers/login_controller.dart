import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:guardian/services/community_service.dart';

class LoginController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Inicia sesión con correo y contraseña
  Future<String?> signInWithEmail(String email, String password) async {
  try {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    return null; // Éxito
  } on FirebaseAuthException catch (e) {
    if (e.code == 'invalid-credential') {
      return 'Usuario o contraseña incorrectos.';
    }
    return _handleAuthError(e);
  } catch (e) {
    return 'Error desconocido: $e';
  }
}


  /// Inicia sesión con Google
  Future<String?> signInWithGoogle() async {
  try {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return 'Inicio de sesión cancelado.';

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await _auth.signInWithCredential(credential);
    
    // Agregar usuario a entidades automáticamente (en background, no bloquea)
    // Iteración 2: Membresía automática en entidades
    // Usar unawaited para ejecutar en background sin bloquear, pero asegurar que se complete
    CommunityService().ensureUserInEntities().catchError((error) {
      print('⚠️ Error agregando usuario a entidades después de login con Google: $error');
    });
    
    return null; // Éxito
  } on FirebaseAuthException catch (e) {
    if (e.code == 'invalid-credential') {
      return 'Hubo un problema al iniciar sesión con Google. Intenta nuevamente.';
    }
    return _handleAuthError(e);
  } catch (e) {
    return 'Error inesperado al iniciar sesión con Google.';
  }
}


  /// Cierra sesión del usuario actual
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  /// Devuelve el usuario actual
  User? get currentUser => _auth.currentUser;

  /// Traduce errores comunes de FirebaseAuth
 String _handleAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return 'Este correo ya está registrado.';
    case 'invalid-email':
      return 'Correo no válido.';
    case 'weak-password':
      return 'Contraseña demasiado débil.';
    case 'user-not-found':
      return 'El usuario no existe.';
    case 'wrong-password':
      return 'Contraseña incorrecta.';
    case 'user-disabled':
      return 'Usuario deshabilitado.';
    default:
      return 'Error: ${e.message}';
  }
}

  /// Registra un nuevo usuario con correo y contraseña
  /// También agrega al usuario a las entidades automáticamente (Iteración 2)
  Future<String?> registerWithEmail(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      // Agregar usuario a entidades automáticamente (en background, no bloquea)
      // Iteración 2: Membresía automática en entidades
      // Usar unawaited para ejecutar en background sin bloquear, pero asegurar que se complete
      CommunityService().ensureUserInEntities().catchError((error) {
        print('⚠️ Error agregando usuario a entidades después de registro: $error');
      });
      
      return null; // Éxito
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Error desconocido: $e';
    }
  }

}
