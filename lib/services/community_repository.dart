import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_constants.dart';
import '../core/app_logger.dart';
import '../models/community_model.dart';

/// Low-level data-access object for community documents.
///
/// Contains only simple CRUD operations without business-logic validation.
/// For validated operations (ownership checks, cascading deletes, etc.) use
/// [CommunityService] instead.
class CommunityRepository {
  static final CommunityRepository _instance = CommunityRepository._internal();
  factory CommunityRepository() => _instance;
  CommunityRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns the community with [communityId], or `null` if not found.
  Future<CommunityModel?> getCommunityById(String communityId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.communities)
          .doc(communityId)
          .get();
      if (!doc.exists) return null;
      return CommunityModel.fromFirestore(doc);
    } catch (e) {
      AppLogger.e('CommunityRepository.getCommunityById', e);
      return null;
    }
  }

  /// Applies a partial [data] update to [communityId].
  Future<bool> updateCommunity(String communityId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(FirestoreCollections.communities)
          .doc(communityId)
          .update(data);
      return true;
    } catch (e) {
      AppLogger.e('CommunityRepository.updateCommunity', e);
      return false;
    }
  }

  /// Deletes [communityId] without any validation.
  ///
  /// Prefer [CommunityService.deleteCommunity] for user-facing deletion with
  /// ownership and cascading checks.
  Future<bool> deleteCommunity(String communityId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.communities)
          .doc(communityId)
          .delete();
      return true;
    } catch (e) {
      AppLogger.e('CommunityRepository.deleteCommunity', e);
      return false;
    }
  }

  /// Returns all communities. Intended for administrative use only.
  Future<List<CommunityModel>> getAllCommunities() async {
    try {
      final snapshot =
          await _firestore.collection(FirestoreCollections.communities).get();
      return snapshot.docs.map(CommunityModel.fromFirestore).toList();
    } catch (e) {
      AppLogger.e('CommunityRepository.getAllCommunities', e);
      return [];
    }
  }
}
