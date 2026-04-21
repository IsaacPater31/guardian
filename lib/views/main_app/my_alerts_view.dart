import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guardian/core/app_constants.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/models/alert_model.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/services/alert_repository.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/services/user_service.dart';
import 'package:guardian/utils/alert_date_range_presets.dart';
import 'package:guardian/views/main_app/widgets/alert_detail_dialog.dart';
import 'package:guardian/views/main_app/widgets/map_filter_sheet.dart';
import 'package:intl/intl.dart';

// ─── Design tokens (aligned with home / alert cards) ───────────────────────
const _kBg = Color(0xFFF8F9FA);
const _kCard = Color(0xFFFFFFFF);
const _kText = Color(0xFF1A1A1A);
const _kSub = Color(0xFF6B7280);
const _kBlue = Color(0xFF007AFF);
const _kAttended = Color(0xFF34C759);
const _kPending = Color(0xFFFF9F0A);

/// Filters for [MyAlertsView] (client-side on top of `getMyAlertsStream`).
class MyAlertsFilters {
  final Set<String> types;
  final String status;
  final String dateRange;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String? communityId;
  /// `all` | `seen` (`viewedCount` > 0) | `none`
  final String readFilter;

  const MyAlertsFilters({
    this.types = const {},
    this.status = 'all',
    this.dateRange = 'all',
    this.customStart,
    this.customEnd,
    this.communityId,
    this.readFilter = 'all',
  });

  MyAlertsFilters copyWith({
    Set<String>? types,
    String? status,
    String? dateRange,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearCommunity = false,
    String? communityId,
    String? readFilter,
    bool clearCustomStart = false,
    bool clearCustomEnd = false,
  }) {
    return MyAlertsFilters(
      types: types ?? this.types,
      status: status ?? this.status,
      dateRange: dateRange ?? this.dateRange,
      customStart: clearCustomStart ? null : (customStart ?? this.customStart),
      customEnd: clearCustomEnd ? null : (customEnd ?? this.customEnd),
      communityId: clearCommunity ? null : (communityId ?? this.communityId),
      readFilter: readFilter ?? this.readFilter,
    );
  }

  int get activeCount {
    var n = 0;
    if (types.isNotEmpty) n++;
    if (status != 'all') n++;
    if (dateRange != 'all') n++;
    if (communityId != null) n++;
    if (readFilter != 'all') n++;
    return n;
  }

  static const MyAlertsFilters empty = MyAlertsFilters();
}

class MyAlertsView extends StatefulWidget {
  const MyAlertsView({super.key});

  @override
  State<MyAlertsView> createState() => _MyAlertsViewState();
}

class _MyAlertsViewState extends State<MyAlertsView> {
  final AlertRepository _repository = AlertRepository();
  final CommunityService _communityService = CommunityService();
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<List<AlertModel>>? _sub;
  List<AlertModel> _alerts = [];
  List<Map<String, dynamic>> _myCommunities = [];
  MyAlertsFilters _filters = MyAlertsFilters.empty;
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCommunities();
    _subscribe();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  Future<void> _loadCommunities() async {
    try {
      final list = await _communityService.getMyCommunities();
      if (mounted) setState(() => _myCommunities = list);
    } catch (_) {}
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = _repository.getMyAlertsStream().listen(
      (list) {
        if (mounted) setState(() => _alerts = list);
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<AlertModel> get _filtered {
    final uid = _userService.currentUserId;
    final email = _userService.currentUserEmail?.toLowerCase();

    Iterable<AlertModel> rows = _alerts.where((a) {
      if (uid != null && a.userId == uid) return true;
      if (email != null &&
          (a.userEmail?.toLowerCase() == email)) {
        return true;
      }
      return false;
    });

    if (_filters.types.isNotEmpty) {
      rows = rows.where((a) => _filters.types.contains(a.alertType));
    }
    if (_filters.status != 'all') {
      rows = rows.where((a) {
        if (_filters.status == 'attended') {
          return a.alertStatus == 'attended';
        }
        return a.alertStatus != 'attended';
      });
    }
    rows = rows.where(
      (a) => alertTimestampInRange(
        a.timestamp,
        _filters.dateRange,
        customStart: _filters.customStart,
        customEnd: _filters.customEnd,
      ),
    );
    if (_filters.communityId != null) {
      final cid = _filters.communityId!;
      rows = rows.where((a) => a.communityIds.contains(cid));
    }
    if (_filters.readFilter == 'seen') {
      rows = rows.where((a) => a.viewedCount > 0);
    } else if (_filters.readFilter == 'none') {
      rows = rows.where((a) => a.viewedCount == 0);
    }

    if (_searchQuery.isNotEmpty) {
      rows = rows.where((a) {
        final hay = [
          a.description ?? '',
          a.alertType,
          a.subtype ?? '',
          a.customDetail ?? '',
        ].join(' ').toLowerCase();
        return hay.contains(_searchQuery);
      });
    }

    final out = rows.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return out;
  }

  void _openFilters() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MyAlertsFilterSheet(
        initial: _filters,
        communities: _myCommunities,
        onApply: (f) {
          setState(() => _filters = f);
        },
      ),
    );
  }

  void _openDetail(AlertModel alert) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDetailDialog(alert: alert),
    );
  }

  Future<void> _onRefresh() async {
    final fresh = await _repository.getMyAlerts();
    if (mounted) setState(() => _alerts = fresh);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mq = MediaQuery.of(context);
    final compact = mq.size.width < 360;
    final filtered = _filtered;
    final user = _userService.currentUser;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _kBg,
        foregroundColor: _kText,
        title: Text(
          l10n.myAlertsTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l10n.myAlertsFilters,
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: _filters.activeCount > 0,
              label: Text('${_filters.activeCount}'),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: user == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.myAlertsSignInRequired,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: _kSub,
                    height: 1.35,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 16,
                    0,
                    compact ? 12 : 16,
                    8,
                  ),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.myAlertsSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded, color: _kSub),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      filled: true,
                      fillColor: _kCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _kBlue, width: 1.2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                if (_filters.activeCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 16, right: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _filters = MyAlertsFilters.empty),
                        icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                        label: Text(l10n.myAlertsClearFilters),
                        style: TextButton.styleFrom(foregroundColor: _kBlue),
                      ),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    color: _kBlue,
                    onRefresh: _onRefresh,
                    child: filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            children: [
                              SizedBox(height: mq.size.height * 0.12),
                              _EmptyMyAlerts(
                                hasAnyAlerts: _alerts.isNotEmpty,
                                l10n: l10n,
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: EdgeInsets.fromLTRB(
                              compact ? 12 : 16,
                              4,
                              compact ? 12 : 16,
                              24,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              return _MyAlertTile(
                                alert: filtered[i],
                                compact: compact,
                                onTap: () => _openDetail(filtered[i]),
                              );
                            },
                          ),
                  ),
                ),
                if (_alerts.length >= AppFirestoreLimits.myAlerts)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      l10n.myAlertsListCapHint(AppFirestoreLimits.myAlerts),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _EmptyMyAlerts extends StatelessWidget {
  final bool hasAnyAlerts;
  final AppLocalizations l10n;

  const _EmptyMyAlerts({
    required this.hasAnyAlerts,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              hasAnyAlerts ? Icons.filter_list_off_rounded : Icons.send_rounded,
              size: 40,
              color: hasAnyAlerts ? _kSub : _kBlue.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            hasAnyAlerts ? l10n.myAlertsEmptyFilteredTitle : l10n.myAlertsEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _kText,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasAnyAlerts
                ? l10n.myAlertsEmptyFilteredSubtitle
                : l10n.myAlertsEmptySubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: _kSub,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyAlertTile extends StatelessWidget {
  final AlertModel alert;
  final bool compact;
  final VoidCallback onTap;

  const _MyAlertTile({
    required this.alert,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = EmergencyTypes.getColor(alert.alertType);
    final icon = EmergencyTypes.getIcon(alert.alertType);
    final typeLabel = EmergencyTypes.getTranslatedType(alert.alertType, context);
    final attended = alert.alertStatus == 'attended';
    final df = DateFormat(compact ? 'd MMM · HH:mm' : 'd MMM yyyy · HH:mm');

    return Material(
      color: _kCard,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: compact ? 22 : 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 14 : 15,
                        color: _kText,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      df.format(alert.timestamp.toLocal()),
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: _kSub,
                      ),
                    ),
                    if (alert.description != null &&
                        alert.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        alert.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _kSub,
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (attended ? _kAttended : _kPending)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (attended ? _kAttended : _kPending)
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            attended
                                ? l10n.alertStatusAttendedShort
                                : l10n.alertStatusNotAttendedShort,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: attended ? _kAttended : _kPending,
                            ),
                          ),
                        ),
                        if (alert.isAnonymous)
                          _smallChip(
                            l10n.anonymous,
                            Colors.orange.shade800,
                            Colors.orange.withValues(alpha: 0.1),
                          ),
                        if (alert.viewedCount > 0)
                          _smallChip(
                            '${l10n.viewCount}: ${alert.viewedCount}',
                            Colors.blue.shade800,
                            Colors.blue.withValues(alpha: 0.08),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _smallChip(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _MyAlertsFilterSheet extends StatefulWidget {
  final MyAlertsFilters initial;
  final List<Map<String, dynamic>> communities;
  final ValueChanged<MyAlertsFilters> onApply;

  const _MyAlertsFilterSheet({
    required this.initial,
    required this.communities,
    required this.onApply,
  });

  @override
  State<_MyAlertsFilterSheet> createState() => _MyAlertsFilterSheetState();
}

class _MyAlertsFilterSheetState extends State<_MyAlertsFilterSheet> {
  late MyAlertsFilters _f;

  @override
  void initState() {
    super.initState();
    _f = widget.initial;
    final ids = widget.communities
        .map((m) => m['id'] as String?)
        .whereType<String>()
        .toSet();
    if (_f.communityId != null && !ids.contains(_f.communityId!)) {
      _f = _f.copyWith(clearCommunity: true);
    }
  }

  void _toggleType(String type) {
    HapticFeedback.selectionClick();
    setState(() {
      final s = Set<String>.from(_f.types);
      if (s.contains(type)) {
        s.remove(type);
      } else {
        s.add(type);
      }
      _f = _f.copyWith(types: s);
    });
  }

  Future<void> _pickCustom(bool start) async {
    final now = DateTime.now();
    final initial = start
        ? (_f.customStart ?? now)
        : (_f.customEnd ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1F2937),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _f = start
          ? _f.copyWith(customStart: picked, dateRange: 'custom')
          : _f.copyWith(customEnd: picked, dateRange: 'custom');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final types = EmergencyTypes.allTypesForFilters;
    final communityIds = widget.communities
        .map((m) => m['id'] as String?)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final safeCommunityValue =
        _f.communityId != null && communityIds.contains(_f.communityId!)
            ? _f.communityId
            : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.myAlertsFilters,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.myAlertsFilterCommunitySection,
                style: _sectionStyle,
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    value: safeCommunityValue,
                    hint: Text(l10n.myAlertsAllCommunities),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.myAlertsAllCommunities),
                      ),
                      ...widget.communities
                          .where((m) =>
                              ((m['id'] as String?) ?? '').isNotEmpty)
                          .map((m) {
                        final id = m['id'] as String;
                        final name = m['name'] as String? ?? id;
                        return DropdownMenuItem<String?>(
                          value: id,
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() {
                      if (v == null) {
                        _f = _f.copyWith(clearCommunity: true);
                      } else {
                        _f = _f.copyWith(communityId: v);
                      }
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(l10n.myAlertsFilterDateSection, style: _sectionStyle),
              const SizedBox(height: 8),
              ...kDateOptions.map((opt) {
                return RadioListTile<String>(
                  dense: true,
                  value: opt['value']!,
                  groupValue: _f.dateRange,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _f = _f.copyWith(
                        dateRange: v,
                        clearCustomStart: v != 'custom',
                        clearCustomEnd: v != 'custom',
                      );
                    });
                  },
                  title: Text(opt['label']!, style: const TextStyle(fontSize: 15)),
                );
              }),
              if (_f.dateRange == 'custom') ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickCustom(true),
                        child: Text(
                          _f.customStart != null
                              ? MaterialLocalizations.of(context)
                                  .formatMediumDate(_f.customStart!)
                              : l10n.myAlertsPickStartDate,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickCustom(false),
                        child: Text(
                          _f.customEnd != null
                              ? MaterialLocalizations.of(context)
                                  .formatMediumDate(_f.customEnd!)
                              : l10n.myAlertsPickEndDate,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(l10n.myAlertsFilterStatusSection, style: _sectionStyle),
              const SizedBox(height: 4),
              ...kStatusOptions.map((opt) {
                return RadioListTile<String>(
                  dense: true,
                  value: opt['value']!,
                  groupValue: _f.status,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _f = _f.copyWith(status: v));
                  },
                  title: Text(opt['label']!, style: const TextStyle(fontSize: 15)),
                );
              }),
              const SizedBox(height: 8),
              Text(l10n.myAlertsEngagementFilter, style: _sectionStyle),
              const SizedBox(height: 4),
              RadioListTile<String>(
                dense: true,
                value: 'all',
                groupValue: _f.readFilter,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _f = _f.copyWith(readFilter: v));
                },
                title: Text(l10n.myAlertsEngagementAll),
              ),
              RadioListTile<String>(
                dense: true,
                value: 'seen',
                groupValue: _f.readFilter,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _f = _f.copyWith(readFilter: v));
                },
                title: Text(l10n.myAlertsEngagementSeen),
              ),
              RadioListTile<String>(
                dense: true,
                value: 'none',
                groupValue: _f.readFilter,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _f = _f.copyWith(readFilter: v));
                },
                title: Text(l10n.myAlertsEngagementNone),
              ),
              const SizedBox(height: 12),
              Text(l10n.myAlertsFilterTypeSection, style: _sectionStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: types.map((typeName) {
                  final sel = _f.types.contains(typeName);
                  final byName = EmergencyTypes.getTypeByName(typeName);
                  final color = (byName?['color'] as Color?) ??
                      EmergencyTypes.getColor(typeName);
                  return FilterChip(
                    label: Text(
                      EmergencyTypes.getTranslatedType(typeName, context),
                      style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white : _kText,
                      ),
                    ),
                    selected: sel,
                    onSelected: (_) => _toggleType(typeName),
                    selectedColor: color,
                    checkmarkColor: Colors.white,
                    backgroundColor: _kBg,
                    side: BorderSide(color: Colors.grey.shade300),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _f = MyAlertsFilters.empty);
                      },
                      child: Text(l10n.myAlertsClearFilters),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onApply(_f);
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1F2937),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(l10n.myAlertsApplyFilters),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static const TextStyle _sectionStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: _kSub,
    letterSpacing: 0.2,
  );
}
