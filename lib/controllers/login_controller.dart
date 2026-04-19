import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:guardian/core/app_logger.dart';
import 'package:guardian/core/app_constants.dart';
import 'package:guardian/services/community_service.dart';

/// Handles user authentication (email/password and Google Sign-In).
///
/// After a successful login or registration the controller also ensures the
/// user is enrolled in all entity communities in the background, so this
/// step never delays the UI transition.
class LoginController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return 'Inicio de sesión cancelado.';

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        return 'No se pudo validar la cuenta de Google. Intenta nuevamente.';
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _upsertUserProfile(userCredential.user);
      _ensureEntitiesInBackground();
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } on PlatformException catch (e) {
      AppLogger.e(
        'LoginController.signInWithGoogle PlatformException '
        '[code=${e.code}] [message=${e.message}]',
        e,
      );
      if (e.code == 'sign_in_failed') {
        return 'No se pudo iniciar sesión con Google en este momento. '
            'Intenta nuevamente o usa tu correo y contraseña.';
      }
      return 'No se pudo completar el inicio de sesión con Google. Intenta nuevamente.';
    } catch (e) {
      AppLogger.e('LoginController.signInWithGoogle', e);
      return 'Error inesperado al iniciar sesión con Google.';
    }
  }

  /// Registers a new user with [email] and [password]. Returns an error
  /// message on failure, or `null` on success.
  Future<String?> registerWithEmail(
    String email,
    String password, {
    required String fullName,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(fullName.trim());
        await user.reload();
      }

      await _upsertUserProfile(user, fullName: fullName.trim());
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

  Future<void> _upsertUserProfile(User? user, {String? fullName}) async {
    if (user == null) return;

    final resolvedName = (fullName?.trim().isNotEmpty ?? false)
        ? fullName!.trim()
        : (user.displayName?.trim().isNotEmpty ?? false)
            ? user.displayName!.trim()
            : (user.email?.split('@').first ?? 'Usuario');

    await _firestore.collection(FirestoreCollections.users).doc(user.uid).set({
      'name': resolvedName,
      'displayName': resolvedName,
      'full_name': resolvedName,
      'email': user.email,
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
