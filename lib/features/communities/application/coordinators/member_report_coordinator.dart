import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/communities/domain/member_report_list_item.dart';
import 'package:guardian/features/communities/domain/member_report_model.dart';
import 'package:guardian/features/communities/data/community_repository.dart';
import 'package:guardian/features/communities/application/coordinators/community_authz.dart';

/// Member report create / list / dismiss for community managers.
class MemberReportCoordinator {
  MemberReportCoordinator({
    CommunityRepository? repository,
    CommunityAuthz? authz,
    FirebaseAuth? auth,
    Future<String?> Function(String communityId)? getUserRole,
  })  : _repo = repository ?? CommunityRepository(),
        _authz = authz ?? CommunityAuthz(),
        _auth = auth ?? FirebaseAuth.instance,
        _getUserRole = getUserRole;

  final CommunityRepository _repo;
  final CommunityAuthz _authz;
  final FirebaseAuth _auth;
  final Future<String?> Function(String communityId)? _getUserRole;

  Future<bool> reportMember({
    required String communityId,
    required String reportedUserId,
    required String reason,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      if (reportedUserId == userId) {
        AppLogger.w('reportMember: cannot report self');
        return false;
      }
      if (await _resolveUserRole(communityId) == null) {
        AppLogger.w('reportMember: caller is not a member');
        return false;
      }

      final report = MemberReportModel(
        communityId: communityId,
        reportedUserId: reportedUserId,
        reportedByUserId: userId,
        reason: reason,
        createdAt: DateTime.now(),
        status: ReportFields.statusPending,
      );

      await _repo.addMemberReport(report.toFirestore());
      AppLogger.d('Member report created');
      return true;
    } catch (e) {
      AppLogger.e('reportMember', e);
      return false;
    }
  }

  Future<List<MemberReportListItem>> getReportsForCommunity(
    String communityId,
  ) async {
    try {
      final callerRole = await _resolveUserRole(communityId);
      if (!await _authz.canReviewReports(communityId, callerRole)) {
        AppLogger.w('getReportsForCommunity: caller is not report manager');
        return [];
      }

      final reportsSnap =
          await _repo.queryPendingReportsForCommunity(communityId);

      final reports = <MemberReportListItem>[];

      for (final reportDoc in reportsSnap.docs) {
        final reportData = reportDoc.data();
        final reportedId =
            reportData[ReportFields.reportedUserId] as String? ?? '';
        final reportedById =
            reportData[ReportFields.reportedByUserId] as String? ?? '';

        final reportedName = await _authz.displayNameForUser(reportedId);
        final reportedByName = await _authz.displayNameForUser(reportedById);

        reports.add(
          MemberReportListItem(
            reportId: reportDoc.id,
            reportedUserId: reportedId,
            reportedUserName: reportedName,
            reportedByUserId: reportedById,
            reportedByUserName: reportedByName,
            reason: reportData[ReportFields.reason] as String? ?? '',
            createdAt: (reportData[ReportFields.createdAt] as Timestamp?)
                    ?.toDate() ??
                DateTime.now(),
            status: reportData[ReportFields.status] as String? ??
                ReportFields.statusPending,
          ),
        );
      }

      return reports;
    } catch (e) {
      AppLogger.e('getReportsForCommunity', e);
      return [];
    }
  }

  Future<bool> dismissReport(String reportId) async {
    try {
      await _repo.updateReport(reportId, {ReportFields.status: ReportFields.statusDismissed});
      AppLogger.d('Report dismissed: $reportId');
      return true;
    } catch (e) {
      AppLogger.e('dismissReport', e);
      return false;
    }
  }

  Future<int> getPendingReportsCount(String communityId) async {
    try {
      final callerRole = await _resolveUserRole(communityId);
      if (!await _authz.canReviewReports(communityId, callerRole)) {
        return 0;
      }
      final snap = await _repo.queryPendingReportsForCount(communityId);
      return snap.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<String?> _resolveUserRole(String communityId) {
    final getter = _getUserRole;
    if (getter != null) return getter(communityId);

    final userId = _auth.currentUser?.uid;
    if (userId == null) return Future.value(null);
    return _repo.findMembershipOf(userId, communityId).then((m) => m?.role);
  }
}
