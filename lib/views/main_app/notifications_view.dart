import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:guardian/core/app_constants.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/services/alert_service.dart';
import 'package:guardian/services/community_message_service.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/views/main_app/widgets/community_message_detail_dialog.dart';

// Tokens alineados con MyAlerts / home (ISO 25010: consistencia).
const _kBg = Color(0xFFF8F9FA);
const _kCard = Color(0xFFFFFFFF);
const _kText = Color(0xFF1A1A1A);
const _kSub = Color(0xFF6B7280);
const _kLine = Color(0xFFE5E7EB);
const _kBlue = Color(0xFF007AFF);

enum _DatePreset { all, today, week, month, custom }

/// Inbox: filtros en pantalla (compactos), lista escaneable, detalle al tocar.
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final CommunityMessageService _messageService = CommunityMessageService();
  final CommunityService _communityService = CommunityService();
  bool _didInvalidateOnKick = false;

  String? _communityFilter;
  _DatePreset _datePreset = _DatePreset.all;
  DateTime? _customStart;
  DateTime? _customEnd;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  bool get _hasFilters =>
      _communityFilter != null || _datePreset != _DatePreset.all;

  List<Map<String, dynamic>> _scopeToMemberships(
    List<Map<String, dynamic>> items,
    Set<String> memberCommunityIds,
  ) {
    return items.where((m) {
      final kind = m[CommunityInboxFields.kind] as String?;
      if (kind == CommunityInboxFields.kindMemberRemoved ||
          kind == CommunityInboxFields.kindMemberAdded ||
          kind == CommunityInboxFields.kindRoleChanged) {
        return true;
      }
      final id = m[CommunityInboxFields.communityId] as String?;
      final ids = (m[CommunityInboxFields.communityIds] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      if (id != null && memberCommunityIds.contains(id)) return true;
      return ids.any(memberCommunityIds.contains);
    }).toList();
  }

  void _maybeInvalidateAlertsOnKick(List<Map<String, dynamic>> items) {
    if (_didInvalidateOnKick) return;
    final hasKick = items.any(
      (m) =>
          m[CommunityInboxFields.kind] ==
              CommunityInboxFields.kindMemberRemoved &&
          m[CommunityInboxFields.read] != true,
    );
    if (!hasKick) return;
    _didInvalidateOnKick = true;
    AlertService().invalidateCommunityCache();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> items) {
    var list = List<Map<String, dynamic>>.from(items);

    if (_communityFilter != null) {
      list = list.where((m) {
        final id = m[CommunityInboxFields.communityId] as String?;
        final ids = (m[CommunityInboxFields.communityIds] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        return id == _communityFilter || ids.contains(_communityFilter);
      }).toList();
    }

    final now = DateTime.now();
    DateTime? start;
    DateTime? end;
    switch (_datePreset) {
      case _DatePreset.all:
        break;
      case _DatePreset.today:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
      case _DatePreset.week:
        start = now.subtract(const Duration(days: 7));
      case _DatePreset.month:
        start = now.subtract(const Duration(days: 30));
      case _DatePreset.custom:
        start = _customStart;
        end = _customEnd != null
            ? DateTime(_customEnd!.year, _customEnd!.month, _customEnd!.day)
                .add(const Duration(days: 1))
            : null;
    }

    if (start != null || end != null) {
      list = list.where((m) {
        final created = _asDate(m[CommunityInboxFields.createdAt]);
        if (created == null) return false;
        if (start != null && created.isBefore(start)) return false;
        if (end != null && !created.isBefore(end)) return false;
        return true;
      }).toList();
    }

    list.sort((a, b) {
      final da = _asDate(a[CommunityInboxFields.createdAt]) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db = _asDate(b[CommunityInboxFields.createdAt]) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return list;
  }

  static DateTime? _asDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return null;
  }

  List<MapEntry<String, String>> _communityOptions(
    List<Map<String, dynamic>> items,
  ) {
    final map = <String, String>{};
    for (final m in items) {
      final id = m[CommunityInboxFields.communityId] as String?;
      final name = (m[CommunityInboxFields.communityName] as String?)?.trim();
      if (id != null && id.isNotEmpty) {
        map[id] = (name != null && name.isNotEmpty) ? name : id;
      }
    }
    final list = map.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return list;
  }

  void _clearFilters() {
    setState(() {
      _communityFilter = null;
      _datePreset = _DatePreset.all;
      _customStart = null;
      _customEnd = null;
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
      helpText: 'Rango de fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (range == null || !mounted) return;
    setState(() {
      _datePreset = _DatePreset.custom;
      _customStart = range.start;
      _customEnd = range.end;
    });
  }

  Future<void> _openMessage(String uid, Map<String, dynamic> message) async {
    final id = message['id'] as String?;
    final read = message[CommunityInboxFields.read] == true;
    if (id != null && !read) {
      await _messageService.markRead(uid, id);
    }
    if (!mounted) return;
    await CommunityMessageDetailDialog.show(context, {
      ...message,
      CommunityInboxFields.read: true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final uid = _userId;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        foregroundColor: _kText,
        centerTitle: true,
        title: Text(
          l10n.notifications,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: uid == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.communityMessagesSignIn,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _kSub,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              )
            : StreamBuilder<List<Map<String, dynamic>>>(
                stream: _communityService.getAllMyCommunitiesStream(),
                builder: (context, membershipSnap) {
                  final memberIds = <String>{
                    for (final c in membershipSnap.data ?? const [])
                      if (c['id'] != null) c['id'] as String,
                  };

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _messageService.watchInbox(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: _kBlue),
                        );
                      }

                      final raw = snapshot.data ?? [];
                      _maybeInvalidateAlertsOnKick(raw);
                      final scoped = _scopeToMemberships(raw, memberIds);
                      final communities = _communityOptions(scoped);
                      final items = _applyFilters(scoped);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _InlineFilters(
                            l10n: l10n,
                            communities: communities,
                            communityFilter: _communityFilter,
                            datePreset: _datePreset,
                            customStart: _customStart,
                            customEnd: _customEnd,
                            hasFilters: _hasFilters,
                            onCommunityChanged: (v) =>
                                setState(() => _communityFilter = v),
                            onDateChanged: (v) => setState(() {
                              _datePreset = v;
                              if (v != _DatePreset.custom) {
                                _customStart = null;
                                _customEnd = null;
                              }
                            }),
                            onPickCustomRange: _pickCustomRange,
                            onClear: _clearFilters,
                          ),
                          Expanded(
                            child: items.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Text(
                                        raw.isEmpty
                                            ? l10n.communityMessagesEmpty
                                            : l10n
                                                .communityMessagesFilteredEmpty,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: _kSub,
                                          fontSize: 15,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      28,
                                    ),
                                    itemCount: items.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, i) {
                                      final m = items[i];
                                      return _InboxRow(
                                        message: m,
                                        onOpen: () => _openMessage(uid, m),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

/// Una sola franja: 2 controles (comunidad + fecha). Sin chips sueltos.
class _InlineFilters extends StatelessWidget {
  const _InlineFilters({
    required this.l10n,
    required this.communities,
    required this.communityFilter,
    required this.datePreset,
    required this.customStart,
    required this.customEnd,
    required this.hasFilters,
    required this.onCommunityChanged,
    required this.onDateChanged,
    required this.onPickCustomRange,
    required this.onClear,
  });

  final AppLocalizations l10n;
  final List<MapEntry<String, String>> communities;
  final String? communityFilter;
  final _DatePreset datePreset;
  final DateTime? customStart;
  final DateTime? customEnd;
  final bool hasFilters;
  final ValueChanged<String?> onCommunityChanged;
  final ValueChanged<_DatePreset> onDateChanged;
  final VoidCallback onPickCustomRange;
  final VoidCallback onClear;

  String get _dateLabel {
    switch (datePreset) {
      case _DatePreset.all:
        return 'Cualquier fecha';
      case _DatePreset.today:
        return 'Hoy';
      case _DatePreset.week:
        return 'Últimos 7 días';
      case _DatePreset.month:
        return 'Últimos 30 días';
      case _DatePreset.custom:
        if (customStart != null && customEnd != null) {
          return '${customStart!.day}/${customStart!.month} – ${customEnd!.day}/${customEnd!.month}';
        }
        return 'Rango personalizado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _FilterField(
                    label: l10n.communityMessageCommunityLabel,
                    value: communityFilter == null
                        ? l10n.myAlertsAllCommunities
                        : (communities
                                .where((e) => e.key == communityFilter)
                                .map((e) => e.value)
                                .firstOrNull ??
                            l10n.myAlertsAllCommunities),
                    onTap: () => _pickCommunity(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FilterField(
                    label: l10n.communityMessageDateLabel,
                    value: _dateLabel,
                    onTap: () => _pickDate(context),
                  ),
                ),
              ],
            ),
            if (hasFilters) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    foregroundColor: _kBlue,
                    minimumSize: const Size(48, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.myAlertsClearFilters,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickCommunity(BuildContext context) async {
    final selected = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                title: Text(
                  l10n.myAlertsAllCommunities,
                  style: TextStyle(
                    fontWeight: communityFilter == null
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _kText,
                  ),
                ),
                trailing: communityFilter == null
                    ? const Icon(Icons.check, color: _kBlue)
                    : null,
                onTap: () => Navigator.pop(ctx, _AllCommunities()),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in communities)
                      ListTile(
                        title: Text(
                          e.value,
                          style: TextStyle(
                            fontWeight: communityFilter == e.key
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _kText,
                          ),
                        ),
                        trailing: communityFilter == e.key
                            ? const Icon(Icons.check, color: _kBlue)
                            : null,
                        onTap: () => Navigator.pop(ctx, e.key),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    if (selected is _AllCommunities) {
      onCommunityChanged(null);
    } else if (selected is String) {
      onCommunityChanged(selected);
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final selected = await showModalBottomSheet<_DatePreset>(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final options = <(_DatePreset, String)>[
          (_DatePreset.all, 'Cualquier fecha'),
          (_DatePreset.today, 'Hoy'),
          (_DatePreset.week, 'Últimos 7 días'),
          (_DatePreset.month, 'Últimos 30 días'),
          (_DatePreset.custom, 'Rango personalizado'),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              for (final opt in options)
                ListTile(
                  title: Text(
                    opt.$2,
                    style: TextStyle(
                      fontWeight: datePreset == opt.$1
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _kText,
                    ),
                  ),
                  trailing: datePreset == opt.$1
                      ? const Icon(Icons.check, color: _kBlue)
                      : null,
                  onTap: () => Navigator.pop(ctx, opt.$1),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    if (selected == _DatePreset.custom) {
      onPickCustomRange();
      return;
    }
    onDateChanged(selected);
  }
}

class _AllCommunities {}

class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kSub,
            ),
            filled: true,
            fillColor: _kCard,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kLine),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kLine),
            ),
            suffixIcon: const Icon(
              Icons.expand_more,
              color: _kSub,
              size: 22,
            ),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.message, required this.onOpen});

  final Map<String, dynamic> message;
  final VoidCallback onOpen;

  bool get _isMessage {
    final kind = message[CommunityInboxFields.kind] as String?;
    return kind == CommunityInboxFields.kindMessage || kind == null;
  }

  @override
  Widget build(BuildContext context) {
    return _isMessage
        ? _MessageRow(message: message, onOpen: onOpen)
        : _MembershipRow(message: message, onOpen: onOpen);
  }
}

/// Mensaje: título → cuerpo → info (comunidad / remitente / hora).
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.onOpen});

  final Map<String, dynamic> message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title =
        (message[CommunityInboxFields.title] as String?)?.trim().isNotEmpty ==
                true
            ? (message[CommunityInboxFields.title] as String).trim()
            : l10n.communityMessageDefaultTitle;
    final body = (message[CommunityInboxFields.body] as String?)?.trim() ?? '';
    final community =
        (message[CommunityInboxFields.communityName] as String?)?.trim();
    final sender =
        (message[CommunityInboxFields.senderName] as String?)?.trim();
    final unread = message[CommunityInboxFields.read] != true;
    final created = _NotificationsViewState._asDate(
      message[CommunityInboxFields.createdAt],
    );
    final when = created != null ? _relativeTime(created) : null;

    final preview = body.isEmpty
        ? null
        : (body.length > 110 ? '${body.substring(0, 110).trimRight()}…' : body);

    final meta = [
      if (community != null && community.isNotEmpty) community,
      if (sender != null && sender.isNotEmpty) sender,
      if (when != null) when,
    ].join(' · ');

    return Semantics(
      button: true,
      label: [
        unread ? l10n.communityMessageUnread : l10n.communityMessageRead,
        title,
        if (preview != null) preview,
        if (meta.isNotEmpty) meta,
        l10n.communityMessageOpenHint,
      ].join('. '),
      child: Material(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: unread ? _kBlue.withValues(alpha: 0.45) : _kLine,
                width: unread ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UnreadDot(unread: unread),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.25,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w600,
                          color: _kText,
                        ),
                      ),
                      if (preview != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                            color: _kText,
                          ),
                        ),
                      ],
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                            color: _kSub,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.chevron_right, color: _kSub, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Membresía: notificación simple (título + hora). Sin estructura de mensaje.
class _MembershipRow extends StatelessWidget {
  const _MembershipRow({required this.message, required this.onOpen});

  final Map<String, dynamic> message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title =
        (message[CommunityInboxFields.title] as String?)?.trim().isNotEmpty ==
                true
            ? (message[CommunityInboxFields.title] as String).trim()
            : _inboxNotificationLabel(context);
    final body = (message[CommunityInboxFields.body] as String?)?.trim() ?? '';
    final unread = message[CommunityInboxFields.read] != true;
    final created = _NotificationsViewState._asDate(
      message[CommunityInboxFields.createdAt],
    );
    final when = created != null ? _relativeTime(created) : null;

    return Semantics(
      button: true,
      label: [
        unread ? l10n.communityMessageUnread : l10n.communityMessageRead,
        _inboxNotificationLabel(context),
        title,
        if (body.isNotEmpty) body,
        if (when != null) when,
        l10n.communityMessageOpenHint,
      ].join('. '),
      child: Material(
        color: unread ? _kCard : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kLine),
            ),
            child: Row(
              children: [
                _UnreadDot(unread: unread),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.25,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w500,
                          color: _kText,
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: _kSub,
                          ),
                        ),
                      ],
                      if (when != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          when,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _kSub,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _kSub, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.unread});

  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(right: 12, top: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unread ? _kBlue : Colors.transparent,
        border: unread ? null : Border.all(color: const Color(0xFFD1D5DB)),
      ),
    );
  }
}

String _relativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'Ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
  if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
  return '${dt.day}/${dt.month}/${dt.year}';
}

String _inboxNotificationLabel(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? 'Notificación'
      : 'Notification';
}
