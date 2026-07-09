import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/services/community_message_service.dart';

/// Notificaciones: mensajes de comunidad.
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final CommunityMessageService _messageService = CommunityMessageService();

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final w = MediaQuery.sizeOf(context).width;
    final pad = w < 360 ? 16.0 : 20.0;
    final uid = _userId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        title: Text(
          l10n.notifications,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 32),
          children: [
            Text(
              l10n.communityMessagesTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            if (uid == null)
              Text(
                l10n.communityMessagesSignIn,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              )
            else
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _messageService.watchInbox(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        l10n.communityMessagesEmpty,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: items.map((m) => _MessageTile(
                      message: m,
                      onOpen: () {
                        final read = m['read'] == true;
                        if (!read) {
                          _messageService.markRead(uid, m['id'] as String);
                        }
                      },
                    )).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, required this.onOpen});

  final Map<String, dynamic> message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = (message['title'] as String?)?.trim() ?? l10n.communityMessageDefaultTitle;
    final body = (message['body'] as String?)?.trim() ?? '';
    final sender = (message['sender_name'] as String?)?.trim();
    final unread = message['read'] != true;

    return Material(
      color: unread ? Colors.white : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread ? const Color(0xFF007AFF).withValues(alpha: 0.25) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                  if (unread)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF007AFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              if (sender != null && sender.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.communityMessageFrom(sender),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              if (body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  body,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
