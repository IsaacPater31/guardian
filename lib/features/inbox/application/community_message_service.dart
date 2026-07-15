import 'package:guardian/features/inbox/data/community_message_repository.dart';
import 'package:guardian/shared/domain/community_inbox_item.dart';

/// Community broadcast messages delivered to the user's inbox.
class CommunityMessageService {
  CommunityMessageService({CommunityMessageRepository? repository})
      : _repository = repository ?? CommunityMessageRepository();

  final CommunityMessageRepository _repository;

  Stream<List<CommunityInboxItem>> watchInbox(String userId) =>
      _repository.watchInbox(userId);

  Stream<bool> watchHasUnread(String userId) =>
      _repository.watchHasUnread(userId);

  Future<void> markRead(String userId, String inboxDocId) =>
      _repository.markRead(userId, inboxDocId);
}
