import 'package:guardian/repositories/community_message_repository.dart';

/// Community broadcast messages delivered to the user's inbox.
class CommunityMessageService {
  CommunityMessageService({CommunityMessageRepository? repository})
      : _repository = repository ?? CommunityMessageRepository();

  final CommunityMessageRepository _repository;

  Stream<List<Map<String, dynamic>>> watchInbox(String userId) =>
      _repository.watchInbox(userId);

  Future<void> markRead(String userId, String inboxDocId) =>
      _repository.markRead(userId, inboxDocId);
}
