import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/domain/member_added_welcome_signal.dart';

/// Maps `member_added_signals` documents ↔ [MemberAddedWelcomeSignal].
class MemberAddedWelcomeMapper {
  MemberAddedWelcomeMapper._();

  static MemberAddedWelcomeSignal fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final name =
        (data[MemberAddedSignalFields.communityName] as String?)?.trim() ?? '';
    final communityId =
        data[MemberAddedSignalFields.communityId] as String? ?? '';
    return MemberAddedWelcomeSignal(
      id: doc.id,
      communityId: communityId,
      communityName: name.isNotEmpty ? name : communityId,
    );
  }
}
