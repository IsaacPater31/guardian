import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_constants.dart';

/// Firestore `users` collection access (profile rows keyed by Firebase Auth UID).
///
/// **Why a repository:** login/sign-up flows should not embed collection paths
/// in the handler; keeps user-document shape in one place.
class UserProfileRepository {
  static final UserProfileRepository _instance = UserProfileRepository._internal();
  factory UserProfileRepository() => _instance;
  UserProfileRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Crea o actualiza el perfil en `users/{uid}`.
  ///
  /// `created_at` solo se escribe si el documento no existe (evita borrar la fecha de alta en cada login).
  Future<void> mergeProfile({
    required String uid,
    required String resolvedName,
    String? email,
  }) async {
    final ref = _firestore.collection(FirestoreCollections.users).doc(uid);
    final snap = await ref.get();
    final normalizedEmail = email != null && email.trim().isNotEmpty
        ? email.trim().toLowerCase()
        : null;

    final payload = <String, dynamic>{
      'name': resolvedName,
      'displayName': resolvedName,
      'full_name': resolvedName,
      'email': normalizedEmail,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (!snap.exists) {
      payload['created_at'] = FieldValue.serverTimestamp();
    }
    await ref.set(payload, SetOptions(merge: true));
  }
}
