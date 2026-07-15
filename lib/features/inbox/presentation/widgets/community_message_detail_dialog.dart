import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/shared/domain/community_inbox_item.dart';
import 'package:intl/intl.dart';

const _kText = Color(0xFF1A1A1A);
const _kSub = Color(0xFF6B7280);
const _kLine = Color(0xFFE5E7EB);
const _kBlue = Color(0xFF007AFF);

/// Detalle encima. Mensaje de comunidad ≠ notificación de membresía.
class CommunityMessageDetailDialog extends StatelessWidget {
  const CommunityMessageDetailDialog({super.key, required this.item});

  final CommunityInboxItem item;

  static Future<void> show(BuildContext context, CommunityInboxItem item) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => CommunityMessageDetailDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return item.isCommunityMessage
        ? _MessageDetail(item: item)
        : _MembershipDetail(item: item);
  }
}

/// Mensaje: título → cuerpo → info abajo (comunidad, remitente, fecha).
class _MessageDetail extends StatelessWidget {
  const _MessageDetail({required this.item});

  final CommunityInboxItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final isSmall = media.size.width < 360;
    final locale = Localizations.localeOf(context).toString();
    final es = Localizations.localeOf(context).languageCode == 'es';

    final title = item.title?.trim().isNotEmpty == true
        ? item.title!.trim()
        : l10n.communityMessageDefaultTitle;
    final body = item.body?.trim() ?? '';
    final sender = item.senderName?.trim();
    final community = item.communityName?.trim();
    final dateText = item.createdAt != null
        ? DateFormat.yMMMd(locale).add_jm().format(item.createdAt!)
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
                  if (hasMeta) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: _kLine),
                    const SizedBox(height: 12),
                    if (community != null && community.isNotEmpty)
                      _MetaLine(
                        label: es ? 'Comunidad' : 'Community',
                        value: community,
                      ),
                    if (sender != null && sender.isNotEmpty) ...[
                      if (community != null && community.isNotEmpty)
                        const SizedBox(height: 8),
                      _MetaLine(
                        label: es ? 'Remitente' : 'Sender',
                        value: sender,
                      ),
                    ],
                    if (dateText != null) ...[
                      if ((community != null && community.isNotEmpty) ||
                          (sender != null && sender.isNotEmpty))
                        const SizedBox(height: 8),
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

class _MembershipDetail extends StatelessWidget {
  const _MembershipDetail({required this.item});

  final CommunityInboxItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final isSmall = media.size.width < 360;
    final locale = Localizations.localeOf(context).toString();

    final title = item.title?.trim().isNotEmpty == true
        ? item.title!.trim()
        : (Localizations.localeOf(context).languageCode == 'es'
            ? 'Notificación'
            : 'Notification');
    final body = item.body?.trim() ?? '';
    final dateText = item.createdAt != null
        ? DateFormat.yMMMd(locale).add_jm().format(item.createdAt!)
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
