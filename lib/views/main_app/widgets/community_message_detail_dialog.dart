import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:guardian/core/app_constants.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

const _kText = Color(0xFF1A1A1A);
const _kSub = Color(0xFF6B7280);
const _kLine = Color(0xFFE5E7EB);
const _kBlue = Color(0xFF007AFF);

bool _isCommunityMessage(Map<String, dynamic> message) {
  final kind = message[CommunityInboxFields.kind] as String?;
  return kind == CommunityInboxFields.kindMessage || kind == null;
}

/// Detalle encima. Mensaje de comunidad ≠ notificación de membresía.
class CommunityMessageDetailDialog extends StatelessWidget {
  const CommunityMessageDetailDialog({super.key, required this.message});

  final Map<String, dynamic> message;

  static Future<void> show(BuildContext context, Map<String, dynamic> message) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => CommunityMessageDetailDialog(message: message),
    );
  }

  DateTime? _createdAt() {
    final ts = message[CommunityInboxFields.createdAt];
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isMessage = _isCommunityMessage(message);
    return isMessage
        ? _MessageDetail(message: message, createdAt: _createdAt())
        : _MembershipDetail(message: message, createdAt: _createdAt());
  }
}

/// Mensaje: título → cuerpo → info abajo (comunidad, remitente, fecha).
class _MessageDetail extends StatelessWidget {
  const _MessageDetail({required this.message, required this.createdAt});

  final Map<String, dynamic> message;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final isSmall = media.size.width < 360;
    final locale = Localizations.localeOf(context).toString();
    final es = Localizations.localeOf(context).languageCode == 'es';

    final title =
        (message[CommunityInboxFields.title] as String?)?.trim().isNotEmpty ==
                true
            ? (message[CommunityInboxFields.title] as String).trim()
            : l10n.communityMessageDefaultTitle;
    final body = (message[CommunityInboxFields.body] as String?)?.trim() ?? '';
    final sender =
        (message[CommunityInboxFields.senderName] as String?)?.trim();
    final community =
        (message[CommunityInboxFields.communityName] as String?)?.trim();
    final dateText = createdAt != null
        ? DateFormat.yMMMd(locale).add_jm().format(createdAt!)
        : null;

    final hasMeta = (community != null && community.isNotEmpty) ||
        (sender != null && sender.isNotEmpty) ||
        dateText != null;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmall ? 16 : 24,
        vertical: isSmall ? 24 : 40,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: media.size.height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogHeader(
              title: title,
              closeLabel: l10n.communityMessageClose,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (body.isNotEmpty)
                      SelectableText(
                        body,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                          color: _kText,
                        ),
                      ),
                    if (hasMeta) ...[
                      const SizedBox(height: 20),
                      const Divider(height: 1, color: _kLine),
                      const SizedBox(height: 14),
                      if (community != null && community.isNotEmpty)
                        _MetaLine(
                          label: l10n.communityMessageCommunityLabel,
                          value: community,
                        ),
                      if (sender != null && sender.isNotEmpty) ...[
                        if (community != null && community.isNotEmpty)
                          const SizedBox(height: 8),
                        _MetaLine(
                          label: es ? 'Enviado por' : 'Sent by',
                          value: sender,
                        ),
                      ],
                      if (dateText != null) ...[
                        if ((community != null && community.isNotEmpty) ||
                            (sender != null && sender.isNotEmpty))
                          const SizedBox(height: 8),
                        _MetaLine(
                          label: l10n.communityMessageDateLabel,
                          value: dateText,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            _CloseButton(label: l10n.communityMessageClose),
          ],
        ),
      ),
    );
  }
}

/// Notificación de membresía: título + texto + hora. Sin estructura de mensaje.
class _MembershipDetail extends StatelessWidget {
  const _MembershipDetail({required this.message, required this.createdAt});

  final Map<String, dynamic> message;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final isSmall = media.size.width < 360;
    final locale = Localizations.localeOf(context).toString();

    final title =
        (message[CommunityInboxFields.title] as String?)?.trim().isNotEmpty ==
                true
            ? (message[CommunityInboxFields.title] as String).trim()
            : (Localizations.localeOf(context).languageCode == 'es'
                ? 'Notificación'
                : 'Notification');
    final body = (message[CommunityInboxFields.body] as String?)?.trim() ?? '';
    final dateText = createdAt != null
        ? DateFormat.yMMMd(locale).add_jm().format(createdAt!)
        : null;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmall ? 16 : 24,
        vertical: isSmall ? 24 : 40,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogHeader(
              title: title,
              closeLabel: l10n.communityMessageClose,
            ),
            const Divider(height: 1, color: _kLine),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (body.isNotEmpty)
                    SelectableText(
                      body,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: _kText,
                      ),
                    ),
                  if (dateText != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _kSub,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _CloseButton(label: l10n.communityMessageClose),
          ],
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title, required this.closeLabel});

  final String title;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: -0.2,
                  color: _kText,
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: closeLabel,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: closeLabel,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.close, color: _kText),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, height: 1.35, color: _kSub),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: _kText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: FilledButton.styleFrom(
            backgroundColor: _kBlue,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
