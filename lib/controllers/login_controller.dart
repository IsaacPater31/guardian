import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:guardian/core/app_logger.dart';
import 'package:guardian/services/community_service.dart';

/// Handles user authentication (email/password and Google Sign-In).
///
/// After a successful login or registration the controller also ensures the
/// user is enrolled in all entity communities in the background, so this
/// step never delays the UI transition.
class LoginController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Signs in with [email] and [password]. Returns an error message on
  /// failure, or `null` on success.
  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Error desconocido: $e';
    }
  }

  /// Signs in with Google. Returns an error message on failure, or `null`
  /// on success.
  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return 'Inicio de sesión cancelado.';

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      _ensureEntitiesInBackground();
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Error inesperado al iniciar sesión con Google.';
    }
  }

  /// Registers a new user with [email] and [password]. Returns an error
  /// message on failure, or `null` on success.
  Future<String?> registerWithEmail(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      _ensureEntitiesInBackground();
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Error desconocido: $e';
    }
  }

  /// Signs out the current user from both Firebase and Google.
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  /// The currently authenticated user, or `null` if not signed in.
  User? get currentUser => _auth.currentUser;

  // ─── Private helpers ──────────────────────────────────────────────────────

  /// Enrolls the user in entity communities without blocking sign-in flow.
  void _ensureEntitiesInBackground() {
    CommunityService().ensureUserInEntities().catchError((error) {
      AppLogger.w('ensureUserInEntities failed after auth: $error');
    });
  }

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
      case 'invalid-credential':
        return 'Credenciales inválidas. Verifica tu correo y contraseña.';
      default:
        return 'Error: ${e.message}';
    }
  }
}
