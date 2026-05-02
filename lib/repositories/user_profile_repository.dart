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

  Future<void> mergeProfile({
    required String uid,
    required String resolvedName,
    String? email,
  }) {
    return _firestore.collection(FirestoreCollections.users).doc(uid).set({
      'name': resolvedName,
      'displayName': resolvedName,
      'full_name': resolvedName,
      'email': email,
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
