import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:guardian/core/app_logger.dart';
import 'package:guardian/models/alert_model.dart';
import 'package:guardian/models/community_model.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:guardian/handlers/alert_handler.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/utils/alert_subtype_display.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/repositories/community_repository.dart';
import 'package:guardian/services/user_service.dart';
// ─── Shared design constants ───────────────────────────────────────────────────
const Color _kAttended  = Color(0xFF34C759); // Apple green
const Color _kPending   = Color(0xFFFF9F0A); // Apple amber
const Color _kSurface   = Color(0xFFF8F9FA);
const Color _kBorder    = Color(0xFFE5E7EB);
const Color _kText      = Color(0xFF1F2937);
const Color _kTextSub   = Color(0xFF6B7280);
const Color _kBluePrim  = Color(0xFF007AFF); // Apple blue
const Color _kDark      = Color(0xFF1C1C1E);
const Color _kError     = Color(0xFFFF3B30);

/// Pill badge showing the attendance status of an alert.
/// Used in the header and anywhere else an at-a-glance signal is needed.
class AlertStatusBadge extends StatelessWidget {
  final bool isAttended;
  final bool large;

  const AlertStatusBadge({
    super.key,
    required this.isAttended,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color  = isAttended ? _kAttended : _kPending;
    final icon   = isAttended ? Icons.check_circle_rounded : Icons.schedule_rounded;
    final label  = isAttended
        ? l10n.alertStatusAttendedShort
        : l10n.alertStatusNotAttendedShort;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical:   large ? 6  : 4,
      ),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: large ? 14 : 11, color: color),
          SizedBox(width: large ? 5 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize:   large ? 13 : 11,
              fontWeight: FontWeight.w600,
              color:      color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class AlertDetailDialog extends StatefulWidget {
  final AlertModel alert;

  const AlertDetailDialog({super.key, required this.alert});

  @override
  State<AlertDetailDialog> createState() => _AlertDetailDialogState();
}

class _AlertDetailDialogState extends State<AlertDetailDialog> {
  final AlertHandler      _alertHandler      = AlertHandler();
  final CommunityService     _communityService     = CommunityService();
  final CommunityRepository  _communityRepository  = CommunityRepository();
  final UserService          _userService          = UserService();

  /// Community id → name **only for communities the current user belongs to**.
  /// Other destinations on the alert are omitted (no label, no UUID).
  final Map<String, String> _communityNames = {};
  bool    _userHasReported      = false;
  int?    _reportsCountOverride;
  bool    _isReporting          = false;

  bool get _isAttended => widget.alert.alertStatus == 'attended';

  String _getTranslatedAlertType() =>
      EmergencyTypes.getTranslatedType(widget.alert.alertType, context);

  @override
  void initState() {
    super.initState();
    if (widget.alert.id != null) {
      _alertHandler.markAlertAsViewed(widget.alert.id!);
    }
    _scheduleCommunityNameLoad();
  }

  @override
  void didUpdateWidget(covariant AlertDetailDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.alert.communityIds, widget.alert.communityIds)) {
      _communityNames.clear();
      _scheduleCommunityNameLoad();
    }
  }

  /// After first frame so [AppLocalizations] is available (not safe in [initState]).
  void _scheduleCommunityNameLoad() {
    if (widget.alert.communityIds.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCommunityNames();
    });
  }

  Future<void> _loadCommunityNames() async {
    final ids = widget.alert.communityIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;

    if (!mounted || AppLocalizations.of(context) == null) return;

    final myNameById = <String, String>{};
    try {
      final mine = await _communityService.getMyCommunities();
      for (final m in mine) {
        final mid = (m['id'] as String?)?.trim();
        final mname = (m['name'] as String?)?.trim();
        if (mid != null && mid.isNotEmpty && mname != null && mname.isNotEmpty) {
          myNameById[mid] = mname;
        }
      }
    } catch (e) {
      AppLogger.e('AlertDetailDialog._loadCommunityNames myCommunities', e);
    }

    // Only show names for communities the user is a member of. Do not resolve
    // or display other IDs (privacy: no "deleted", no UUID, no guessing).
    final resolved = <String, String>{};
    for (final id in ids) {
      final name = myNameById[id];
      if (name != null && name.isNotEmpty) resolved[id] = name;
    }

    if (!mounted) return;
    setState(() {
      _communityNames
        ..clear()
        ..addAll(resolved);
    });
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sw       = MediaQuery.of(context).size.width;
    final sh       = MediaQuery.of(context).size.height;
    final isSmall  = sw < 360;
    final padding  = isSmall ? 14.0 : 20.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmall ? 10 : 16,
        vertical:   isSmall ? 10 : 20,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: sh * (isSmall ? 0.90 : 0.87),
          maxWidth:  (sw * 0.96).clamp(0.0, 480.0),
        ),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              spreadRadius: 0,
              offset:     const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isSmall),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Estado de atención ───────────────────────────────────
                    _buildStatusSection(isSmall),
                    SizedBox(height: isSmall ? 12 : 16),

                    // ── Comunidad (solo miembros) ─────────────────────────────
                    if (_communityNames.isNotEmpty) ...[
                      _buildCommunityInfoSection(isSmall),
                      SizedBox(height: isSmall ? 12 : 16),
                    ],

                    // ── Tipo principal + detalle / subtipo ────────────────────
                    _buildAlertTypeAndSubtypeBodySection(isSmall),
                    SizedBox(height: isSmall ? 12 : 16),

                    // ── Anonimato ─────────────────────────────────────────────
                    _buildAnonymityHighlightSection(isSmall),
                    SizedBox(height: isSmall ? 12 : 16),

                    // ── Fecha y hora (absoluta) ──────────────────────────────
                    _buildDateTimeDetailSection(isSmall),
                    SizedBox(height: isSmall ? 12 : 16),

                    // ── Mensaje ──────────────────────────────────────────────
                    if (widget.alert.description != null && widget.alert.description!.isNotEmpty) ...[
                      _buildDescriptionSection(),
                      SizedBox(height: isSmall ? 12 : 16),
                    ],

                    // ── Counters ─────────────────────────────────────────────
                    if (widget.alert.forwardsCount > 0 ||
                        (_reportsCountOverride ?? widget.alert.reportsCount) > 0) ...[
                      _buildCountersSection(),
                      SizedBox(height: isSmall ? 12 : 16),
                    ],

                    // ── Location ─────────────────────────────────────────────
                    if (widget.alert.shareLocation && widget.alert.location != null) ...[
                      _buildLocationSection(),
                      const SizedBox(height: 12),
                      _buildLocationMapSection(isSmall),
                      SizedBox(height: isSmall ? 12 : 16),
                    ],

                    // ── Additional info ──────────────────────────────────────
                    _buildAdditionalInfoSection(),

                    if (widget.alert.imageBase64 != null &&
                        widget.alert.imageBase64!.isNotEmpty) ...[
                      SizedBox(height: isSmall ? 12 : 16),
                      _buildImageAttachmentsGallery(isSmall),
                    ],

                    if (widget.alert.audioBase64 != null &&
                        widget.alert.audioBase64!.isNotEmpty) ...[
                      SizedBox(height: isSmall ? 12 : 16),
                      _buildAudioAttachmentNotice(isSmall),
                    ],

                    SizedBox(height: isSmall ? 8 : 16),
                  ],
                ),
              ),
            ),
            _buildActionButtons(context, isSmall),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isSmall) {
    final alertColor = _getAlertColor(widget.alert.alertType);

    return Container(
      decoration: BoxDecoration(
        color:        alertColor,
        borderRadius: const BorderRadius.only(
          topLeft:  Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color:      alertColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        isSmall ? 16 : 24,
        isSmall ? 20 : 28,
        isSmall ? 16 : 24,
        isSmall ? 20 : 28,
      ),
      child: Column(
        children: [
          // Alert icon circle
          Container(
            width:  isSmall ? 56 : 72,
            height: isSmall ? 56 : 72,
            decoration: BoxDecoration(
              color:  Colors.white.withValues(alpha: 0.25),
              shape:  BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset:     const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              _getAlertIcon(widget.alert.alertType),
              color: Colors.white,
              size:  isSmall ? 26 : 36,
            ),
          ),

          SizedBox(height: isSmall ? 12 : 16),

          // Tipo principal primero; subtipo destacado debajo (Policía → Robo).
          Text(
            _getTranslatedAlertType(),
            style: TextStyle(
              fontSize:   isSmall ? 19 : 22,
              fontWeight: FontWeight.w800,
              color:      Colors.white,
              letterSpacing: 0.15,
              height:     1.2,
            ),
            textAlign: TextAlign.center,
          ),
          if (AlertSubtypeDisplay.line(
                context,
                widget.alert.alertType,
                widget.alert.subtype,
                widget.alert.customDetail,
              ).isNotEmpty) ...[
            SizedBox(height: isSmall ? 8 : 10),
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize:   isSmall ? 16 : 18,
                  fontWeight: FontWeight.w800,
                  color:      Colors.white,
                  height:     1.2,
                ),
                children: [
                  TextSpan(
                    text: '→ ',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: AlertSubtypeDisplay.line(
                      context,
                      widget.alert.alertType,
                      widget.alert.subtype,
                      widget.alert.customDetail,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],

          SizedBox(height: isSmall ? 8 : 10),

          // Datetime pill
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 10 : 12,
              vertical:   isSmall ? 4  : 6,
            ),
            decoration: BoxDecoration(
              color:        Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatDateTime(widget.alert.timestamp),
              style: TextStyle(
                fontSize:   isSmall ? 11 : 13,
                color:      Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          SizedBox(height: isSmall ? 10 : 12),

          // ── Status badge — bright, on colored background ──────────────────
          _buildHeaderStatusBadge(isSmall),
        ],
      ),
    );
  }

  Widget _buildHeaderStatusBadge(bool isSmall) {
    final color = _isAttended ? Colors.white : Colors.white.withValues(alpha: 0.88);
    final bg    = _isAttended
        ? Colors.white.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.15);
    final border = _isAttended
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.35);
    final l10n = AppLocalizations.of(context)!;
    final icon  = _isAttended ? Icons.check_circle_rounded : Icons.schedule_rounded;
    final label = _isAttended
        ? l10n.alertStatusAttendedShort
        : l10n.alertStatusNotAttendedShort;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 14 : 18,
        vertical:   isSmall ? 6  : 8,
      ),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(24),
        border:       Border.all(color: border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,  size: isSmall ? 14 : 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize:   isSmall ? 13 : 14,
              fontWeight: FontWeight.w700,
              color:      color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Status section (info card in body) ─────────────────────────────────────
  Widget _buildStatusSection(bool isSmall) {
    final l10n = AppLocalizations.of(context)!;
    final color   = _isAttended ? _kAttended : _kPending;
    final bgColor = color.withValues(alpha: 0.08);
    final icon    = _isAttended ? Icons.verified_rounded : Icons.pending_actions_rounded;
    final title   = _isAttended
        ? l10n.alertStatusAttendedShort
        : l10n.alertStatusNotAttendedShort;
    final sub     = _isAttended
        ? l10n.alertStatusAttendedLong
        : l10n.alertStatusPendingLong;

    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding:    const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.15),
              shape:        BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.alertStatusSectionHeading,
                  style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                    color:      color.withValues(alpha: 0.75),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                    color:      color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    color:    color.withValues(alpha: 0.75),
                    height:   1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Communities info — multi-community chips ───────────────────────────────
  Widget _buildCommunityInfoSection(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color:        const Color(0xFF007AFF).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:    const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:        const Color(0xFF007AFF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.groups_2_rounded, color: Color(0xFF007AFF), size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.communitiesHeadingShort.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kBluePrim.withValues(alpha: 0.67), letterSpacing: 0.6),
                ),
                Text(
                  () {
                    final n = _communityNames.length;
                    final isEs =
                        Localizations.localeOf(context).languageCode == 'es';
                    final plural = isEs
                        ? (n == 1 ? '' : 'es')
                        : (n == 1 ? 'y' : 'ies');
                    return AppLocalizations.of(context)!
                        .communityCount(n, plural);
                  }(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final rawId in widget.alert.communityIds)
                if (_communityNames.containsKey(rawId.trim()))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:        const Color(0xFF007AFF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border:       Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.people_rounded, size: 12, color: Color(0xFF007AFF)),
                      const SizedBox(width: 5),
                      Text(
                        _communityNames[rawId.trim()]!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
                      ),
                    ]),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Cuerpo: tipo principal + subtipo (misma jerarquía que el encabezado) ───
  Widget _buildAlertTypeAndSubtypeBodySection(bool isSmall) {
    final l10n    = AppLocalizations.of(context)!;
    final alertColor = _getAlertColor(widget.alert.alertType);
    final main   = _getTranslatedAlertType();
    final sub    = AlertSubtypeDisplay.line(
      context,
      widget.alert.alertType,
      widget.alert.subtype,
      widget.alert.customDetail,
    );
    final subText = sub.isNotEmpty ? sub : l10n.alertDetailNoSubtype;

    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color:  alertColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: alertColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getAlertIcon(widget.alert.alertType), color: alertColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.alertDetailMainTypeLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.w700,
                        color:      alertColor.withValues(alpha: 0.75),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      main,
                      style: TextStyle(
                        fontSize:   isSmall ? 17 : 18,
                        fontWeight: FontWeight.w800,
                        color:      alertColor,
                        height:     1.2,
                      ),
                    ),
                    SizedBox(height: isSmall ? 12 : 14),
                    Text(
                      l10n.alertDetailSubtypeLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.w700,
                        color:      _kTextSub,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subText,
                      style: const TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.w800,
                        color:      _kText,
                        height:     1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnonymityHighlightSection(bool isSmall) {
    final l10n = AppLocalizations.of(context)!;
    final anon = widget.alert.isAnonymous;
    final fg   = anon ? const Color(0xFFB45309) : const Color(0xFF1B7F3A);
    final bg   = anon ? Colors.orange.withValues(alpha: 0.1) : const Color(0xFF34C759).withValues(alpha: 0.1);
    final bd   = anon ? Colors.orange.withValues(alpha: 0.35) : const Color(0xFF34C759).withValues(alpha: 0.35);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: bd, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.alertDetailAnonymityHeading.toUpperCase(),
            style: TextStyle(
              fontSize:   10,
              fontWeight: FontWeight.w700,
              color:      fg.withValues(alpha: 0.8),
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: isSmall ? 8 : 10),
          Row(
            children: [
              Icon(
                anon ? Icons.visibility_off_rounded : Icons.verified_user_rounded,
                color: fg,
                size: isSmall ? 22 : 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  anon ? l10n.anonymousReport : l10n.identifiedReport,
                  style: TextStyle(
                    fontSize:   isSmall ? 15 : 16,
                    fontWeight: FontWeight.w800,
                    color:      fg,
                    height:     1.25,
                  ),
                ),
              ),
            ],
          ),
          if (!anon && widget.alert.userName != null && widget.alert.userName!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.reportedBy}: ${widget.alert.userName!.trim()}',
              style: const TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      _kTextSub,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateTimeDetailSection(bool isSmall) {
    final l10n = AppLocalizations.of(context)!;
    return _buildInfoCard(
      icon:      Icons.schedule_rounded,
      iconColor: _kBluePrim,
      iconBg:    _kBluePrim.withValues(alpha: 0.1),
      label:     l10n.alertDetailDatetimeLabel,
      value:     _formatFullDateTimeForDetail(widget.alert.timestamp),
    );
  }

  String _formatFullDateTimeForDetail(DateTime dt) {
    final locale = Localizations.localeOf(context).toString();
    try {
      return DateFormat.yMMMMEEEEd(locale).add_Hm().format(dt);
    } catch (_) {
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    }
  }

  // ─── Description ─────────────────────────────────────────────────────────────
  Widget _buildDescriptionSection() {
    return _buildInfoCard(
      icon:      Icons.chat_bubble_outline_rounded,
      iconColor: _kText,
      iconBg:    _kText.withValues(alpha: 0.08),
      label:     AppLocalizations.of(context)!.alertDetailMessageLabel,
      value:     widget.alert.description!,
    );
  }

  // ─── Counters ────────────────────────────────────────────────────────────────
  Widget _buildCountersSection() {
    final reports = _reportsCountOverride ?? widget.alert.reportsCount;
    return Row(
      children: [
        if (widget.alert.forwardsCount > 0)
          Expanded(child: _buildCounterChip(
            icon: Icons.forward_rounded, color: Colors.blue,
            count: widget.alert.forwardsCount,
            singular: 'reenvío', plural: 'reenvíos',
          )),
        if (widget.alert.forwardsCount > 0 && reports > 0)
          const SizedBox(width: 12),
        if (reports > 0)
          Expanded(child: _buildCounterChip(
            icon: Icons.report_rounded, color: Colors.orange,
            count: reports,
            singular: 'reporte', plural: 'reportes',
          )),
      ],
    );
  }

  Widget _buildCounterChip({
    required IconData icon,
    required Color color,
    required int count,
    required String singular,
    required String plural,
  }) {
    return Container(
      padding:    const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            '$count ${count == 1 ? singular : plural}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  // ─── Location ────────────────────────────────────────────────────────────────
  Widget _buildLocationSection() {
    return _buildInfoCard(
      icon:      Icons.location_on_rounded,
      iconColor: Colors.green,
      iconBg:    Colors.green.withValues(alpha: 0.1),
      label:     AppLocalizations.of(context)!.location,
      value:
          '${widget.alert.location!.latitude.toStringAsFixed(6)}, ${widget.alert.location!.longitude.toStringAsFixed(6)}',
    );
  }

  Widget _buildLocationMapSection(bool isSmall) {
    if (widget.alert.location == null) return const SizedBox.shrink();
    return Container(
      height: isSmall ? 200 : 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  widget.alert.location!.latitude,
                  widget.alert.location!.longitude,
                ),
                initialZoom: 16.0,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.guardian',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(widget.alert.location!.latitude, widget.alert.location!.longitude),
                    width: 40, height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getAlertColor(widget.alert.alertType),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Icon(_getAlertIcon(widget.alert.alertType), color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ],
            ),
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context)!.alertLocation,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Additional info ─────────────────────────────────────────────────────────
  Widget _buildAdditionalInfoSection() {
    return Container(
      padding:    const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        _kSurface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INFORMACIÓN ADICIONAL',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kTextSub, letterSpacing: 0.8),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            icon:  widget.alert.shareLocation ? Icons.location_on_rounded : Icons.location_off_rounded,
            color: widget.alert.shareLocation ? Colors.green : _kTextSub,
            label: widget.alert.shareLocation
                ? AppLocalizations.of(context)!.locationShared
                : AppLocalizations.of(context)!.locationNotShared,
          ),
          if (widget.alert.viewedCount > 0) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              icon:  Icons.visibility_rounded,
              color: _kBluePrim,
              label:
                  '${AppLocalizations.of(context)!.viewedBy} ${widget.alert.viewedCount} ${widget.alert.viewedCount > 1 ? AppLocalizations.of(context)!.people : AppLocalizations.of(context)!.person}',
            ),
          ],
          if (widget.alert.attachmentPlaceholders.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              icon: Icons.info_outline_rounded,
              color: _kTextSub,
              label: widget.alert.attachmentPlaceholders.join(' · '),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required Color color, required String label}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500, height: 1.3),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioAttachmentNotice(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mic_rounded, color: Colors.deepPurple.shade700, size: isSmall ? 22 : 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Esta alerta incluye un clip de audio adjunto.',
              style: TextStyle(
                fontSize: isSmall ? 14 : 15,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageAttachmentsGallery(bool isSmall) {
    final l10n = AppLocalizations.of(context)!;
    final list = widget.alert.imageBase64!;
    final maxH = isSmall ? 200.0 : 260.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color: _kBluePrim.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBluePrim.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_outlined, color: _kBluePrim, size: isSmall ? 22 : 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.imagesAttached,
                  style: TextStyle(
                    fontSize: isSmall ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) SizedBox(height: isSmall ? 10 : 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, c) {
                  try {
                    final bytes = base64Decode(list[i]);
                    return Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      width: c.maxWidth,
                      height: maxH,
                      errorBuilder: (_, __, ___) => Container(
                        width: double.infinity,
                        height: 80,
                        alignment: Alignment.center,
                        color: _kSurface,
                        child: Text(
                          'Error al cargar imagen ${i + 1}',
                          style: TextStyle(color: _kTextSub, fontSize: 13),
                        ),
                      ),
                    );
                  } catch (_) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: _kSurface,
                      child: Text(
                        'No se pudo mostrar la imagen ${i + 1}.',
                        style: TextStyle(color: _kTextSub, fontSize: isSmall ? 13 : 14),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Action buttons ──────────────────────────────────────────────────────────
  Widget _buildActionButtons(BuildContext context, bool isSmall) {
    return Container(
      padding: EdgeInsets.fromLTRB(isSmall ? 14 : 20, isSmall ? 14 : 18, isSmall ? 14 : 20, isSmall ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reenviar (keeps its function — creates new alerts in other communities)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.alert.id != null ? _showForwardDialog : null,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: isSmall ? 13 : 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: _kBluePrim.withValues(alpha: 0.5), width: 1.5),
              ),
              icon: const Icon(Icons.forward_rounded, size: 18),
              label: Text(
                'Reenviar a comunidad',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          SizedBox(height: isSmall ? 8 : 10),

          // Reportar + Cerrar
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (widget.alert.id != null && !_hasUserReported && !_isReporting)
                      ? _showReportConfirm
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(
                      color: _hasUserReported ? Colors.grey.withValues(alpha: 0.4) : _kBluePrim.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  icon: _isReporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _hasUserReported ? Icons.check_circle_rounded : Icons.report_rounded,
                          size: 16,
                          color: _hasUserReported ? Colors.grey : _kBluePrim,
                        ),
                  label: Text(
                    _hasUserReported ? 'Reportada' : (_isReporting ? 'Reportando…' : 'Reportar'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _hasUserReported ? Colors.grey : _kBluePrim,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getAlertColor(widget.alert.alertType),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    shadowColor: _getAlertColor(widget.alert.alertType).withValues(alpha: 0.3),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.close,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Reusable card builder ───────────────────────────────────────────────────
  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Container(
      padding:    const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        _kSurface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:    const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: _kTextSub, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kText, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reporting ──────────────────────────────────────────────────────────────
  bool get _hasUserReported {
    final uid = _userService.currentUser?.uid ?? '';
    return _userHasReported || (uid.isNotEmpty && widget.alert.reportedBy.contains(uid));
  }

  Future<void> _showReportConfirm() async {
    if (widget.alert.id == null || _hasUserReported || _isReporting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          Icon(Icons.report_problem_rounded, color: Colors.orange[700]),
          const SizedBox(width: 8),
          const Text('Reportar alerta'),
        ]),
        content: const Text(
          '¿Deseas reportar esta alerta como inapropiada o con contenido problemático? Solo puedes reportar una vez.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white),
            child: const Text('Reportar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isReporting = true);
    try {
      await _alertHandler.reportAlert(widget.alert.id!);
      if (mounted) {
        setState(() {
          _userHasReported = true;
          _reportsCountOverride = (widget.alert.reportsCount + 1);
          _isReporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Alerta reportada correctamente'),
          ]),
          backgroundColor: _kDark,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReporting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _kError,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  // ─── Forward dialog ──────────────────────────────────────────────────────────
  Future<void> _showForwardDialog() async {
    if (widget.alert.id == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final allCommunities = await _communityService.getMyCommunities();
      if (mounted) Navigator.pop(context);

      CommunityModel? originalCommunity;
      bool canForwardToEntities = true;

      if (widget.alert.communityId != null && widget.alert.communityId!.isNotEmpty) {
        originalCommunity = await _communityRepository.getCommunityById(widget.alert.communityId!);
        canForwardToEntities = originalCommunity?.allowForwardToEntities ?? true;
      }

      final availableCommunities = allCommunities.where((c) {
        final id       = c['id'] as String;
        final isEntity = c['is_entity'] as bool;
        // Exclude communities already in this alert's communityIds
        if (widget.alert.communityIds.contains(id)) return false;
        if (isEntity && !canForwardToEntities) return false;
        return true;
      }).toList();

      if (availableCommunities.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No hay comunidades disponibles para reenviar'),
            backgroundColor: _kDark,
          ));
        }
        return;
      }

      if (!mounted) return;

      final selectedIds = await showDialog<Set<String>>(
        context: context,
        builder: (_) => _ForwardAlertDialog(
          availableCommunities:  availableCommunities,
          canForwardToEntities:  canForwardToEntities,
        ),
      );

      if (selectedIds == null || selectedIds.isEmpty) return;
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final count = await _alertHandler.forwardAlert(
          alertId:             widget.alert.id!,
          targetCommunityIds:  selectedIds.toList(),
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Alerta reenviada a $count ${count == 1 ? 'comunidad' : 'comunidades'}'),
            backgroundColor: _kDark,
            duration: const Duration(seconds: 3),
          ));
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error reenviando: ${e.toString()}'),
            backgroundColor: _kError,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: _kError,
        ));
      }
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  IconData _getAlertIcon(String alertType) {
    switch (alertType) {
      case 'HEALTH':       return Icons.medical_services_rounded;
      case 'HOME_HELP':    return Icons.home_rounded;
      case 'POLICE':       return Icons.shield_rounded;
      case 'FIRE':         return Icons.local_fire_department_rounded;
      case 'SECURITY_BREACH': return Icons.security_update_warning_rounded;
      case 'ACCOMPANIMENT':return Icons.people_rounded;
      case 'ENVIRONMENTAL':return Icons.eco_rounded;
      case 'ROAD_EMERGENCY': return Icons.directions_car_rounded;
      case 'URGENCY':      return Icons.emergency_rounded;
      case 'HARASSMENT':   return Icons.shield_rounded;
      case 'ROBBERY':      return Icons.person_off_rounded;
      case 'ACCIDENT':     return Icons.car_crash_rounded;
      case 'STREET ESCORT':return Icons.people_rounded;
      case 'UNSAFETY':     return Icons.warning_rounded;
      case 'PHYSICAL RISK':return Icons.accessibility_rounded;
      case 'PUBLIC SERVICES EMERGENCY': return Icons.construction_rounded;
      case 'VIAL EMERGENCY': return Icons.directions_car_rounded;
      case 'ASSISTANCE':   return Icons.help_rounded;
      case 'EMERGENCY':    return Icons.emergency_rounded;
      default:             return Icons.warning_rounded;
    }
  }

  Color _getAlertColor(String alertType) {
    switch (alertType) {
      case 'HEALTH':       return const Color(0xFF26C6DA);
      case 'HOME_HELP':    return const Color(0xFF66BB6A);
      case 'POLICE':       return const Color(0xFF1565C0);
      case 'FIRE':         return const Color(0xFFE53935);
      case 'SECURITY_BREACH': return const Color(0xFFC62828);
      case 'ACCOMPANIMENT':return const Color(0xFF8E24AA);
      case 'ENVIRONMENTAL':return const Color(0xFF43A047);
      case 'ROAD_EMERGENCY':return const Color(0xFFFF7043);
      case 'URGENCY':     return const Color(0xFFF44336);
      case 'HARASSMENT':  return const Color(0xFFEC407A);
      case 'ROBBERY':      return const Color(0xFF9C27B0);
      case 'EMERGENCY':    return const Color(0xFFF44336);
      case 'ACCIDENT':     return const Color(0xFFFF9800);
      case 'UNSAFETY':     return const Color(0xFFFF9800);
      case 'PHYSICAL RISK':return const Color(0xFF673AB7);
      case 'PUBLIC SERVICES EMERGENCY': return const Color(0xFFFFC107);
      case 'VIAL EMERGENCY': return const Color(0xFF00BCD4);
      case 'ASSISTANCE':   return const Color(0xFF4CAF50);
      case 'STREET ESCORT':return const Color(0xFF2196F3);
      default:             return const Color(0xFF9E9E9E);
    }
  }

  String _formatDateTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours   < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays    == 1) return 'Ayer';
    return 'Hace ${diff.inDays}d';
  }

}

// ─── Forward alert dialog ─────────────────────────────────────────────────────
class _ForwardAlertDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableCommunities;
  final bool canForwardToEntities;

  const _ForwardAlertDialog({
    required this.availableCommunities,
    required this.canForwardToEntities,
  });

  @override
  State<_ForwardAlertDialog> createState() => _ForwardAlertDialogState();
}

class _ForwardAlertDialogState extends State<_ForwardAlertDialog> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final entities   = widget.availableCommunities.where((c) => c['is_entity'] == true).toList();
    final normals    = widget.availableCommunities.where((c) => c['is_entity'] != true).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.forward_rounded, color: _kDark),
        SizedBox(width: 8),
        Text('Reenviar Alerta'),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selecciona a qué comunidades reenviar:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              if (entities.isNotEmpty && widget.canForwardToEntities) ...[
                const Text('Entidades Oficiales', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kBluePrim, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                ...entities.map(_buildCommunityTile),
                const SizedBox(height: 16),
              ],
              if (normals.isNotEmpty) ...[
                const Text('Comunidades', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                ...normals.map(_buildCommunityTile),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _selectedIds.isEmpty ? null : () => Navigator.pop(context, _selectedIds),
          style: ElevatedButton.styleFrom(backgroundColor: _kDark, foregroundColor: Colors.white),
          child: Text('Reenviar (${_selectedIds.length})'),
        ),
      ],
    );
  }

  Widget _buildCommunityTile(Map<String, dynamic> community) {
    final id       = community['id'] as String;
    final name     = community['name'] as String;
    final isEntity = community['is_entity'] as bool;
    final selected = _selectedIds.contains(id);

    return Card(
      margin:     const EdgeInsets.only(bottom: 8),
      elevation:  0,
      color:      selected ? _kBluePrim.withValues(alpha: 0.06) : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? _kBluePrim.withValues(alpha: 0.4) : _kBorder,
          width: 1.5,
        ),
      ),
      child: CheckboxListTile(
        value:    selected,
        onChanged: (v) => setState(() => v == true ? _selectedIds.add(id) : _selectedIds.remove(id)),
        activeColor: _kBluePrim,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: isEntity
            ? Container(
                margin:     const EdgeInsets.only(top: 4),
                padding:    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:        _kBluePrim.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Entidad Oficial', style: TextStyle(fontSize: 10, color: _kBluePrim, fontWeight: FontWeight.w600)),
              )
            : null,
        secondary: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color:        isEntity ? _kBluePrim.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            isEntity ? Icons.shield_rounded : Icons.people_rounded,
            color: isEntity ? _kBluePrim : Colors.green,
            size: 18,
          ),
        ),
      ),
    );
  }
}