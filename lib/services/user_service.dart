import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Obtiene el usuario actual
  User? get currentUser => _auth.currentUser;

  /// Obtiene el ID del usuario actual
  String? get currentUserId => _auth.currentUser?.uid;

  /// Obtiene el email del usuario actual
  String? get currentUserEmail => _auth.currentUser?.email;

  /// Obtiene el nombre del usuario actual
  String? get currentUserName {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    // Priorizar displayName, luego email sin dominio
    return user.displayName ?? user.email?.split('@')[0];
  }

  /// Verifica si hay un usuario autenticado
  bool get isUserLoggedIn => _auth.currentUser != null;

  /// Obtiene el stream de cambios de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Verifica si un usuario puede enviar alertas
  bool canUserSendAlerts() {
    return isUserLoggedIn;
  }

  /// Obtiene información del usuario para una alerta
  Map<String, String?> getUserInfoForAlert() {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'userId': null,
        'userEmail': null,
        'userName': null,
      };
    }

    return {
      'userId': user.uid,
      'userEmail': user.email,
      'userName': user.displayName ?? user.email?.split('@')[0],
    };
  }

  /// Verifica si un usuario es el propietario de una alerta
  bool isUserOwnerOfAlert(String? alertUserId, String? alertUserEmail) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    // Verificar por userId
    if (alertUserId != null && alertUserId == currentUser.uid) {
      return true;
    }

    // Verificar por email
    if (alertUserEmail != null && alertUserEmail == currentUser.email) {
      return true;
    }

    return false;
  }

  /// Obtiene el nombre de usuario para mostrar en alertas
  String? getUserDisplayName({bool isAnonymous = false}) {
    if (isAnonymous) return null;
    
    final user = _auth.currentUser;
    if (user == null) return null;
    
    return user.displayName ?? user.email?.split('@')[0];
  }

  /// Verifica si el usuario tiene permisos para ver una alerta
  bool canUserViewAlert(String? alertUserId, String? alertUserEmail, bool isAnonymous) {
    // Si la alerta es anónima, siempre se puede ver
    if (isAnonymous) return true;
    
    // Si no hay usuario logueado, no puede ver alertas no anónimas
    if (!isUserLoggedIn) return false;
    
    // Si es el propietario de la alerta, no debe verla (para evitar duplicados)
    if (isUserOwnerOfAlert(alertUserId, alertUserEmail)) {
      return false;
    }
    
    return true;
  }
}
