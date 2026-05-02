import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/core/app_constants.dart';
import 'package:guardian/models/alert_model.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/services/alert_service.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/services/user_service.dart';
import 'package:guardian/utils/alert_subtype_display.dart';
import 'package:guardian/views/main_app/widgets/alert_detail_dialog.dart';
import 'package:guardian/views/main_app/community_settings_view.dart';
import 'package:guardian/views/main_app/community_members_view.dart';
import 'package:latlong2/latlong.dart';

class CommunityFeedView extends StatefulWidget {
  final String communityId;
  final String communityName;
  final bool isEntity;

  const CommunityFeedView({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.isEntity,
  });

  @override
  State<CommunityFeedView> createState() => _CommunityFeedViewState();
}

class _CommunityFeedViewState extends State<CommunityFeedView>
    with SingleTickerProviderStateMixin {
  final AlertService _alertService = AlertService();
  final CommunityService _communityService = CommunityService();
  final UserService _userService = UserService();
  String? _userRole;
  bool _isLoadingRole = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadUserRole();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _openAddMembers() {
    if (_userRole != MemberFields.roleAdmin) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityMembersView(
          communityId: widget.communityId,
          communityName: widget.communityName,
          userRole: _userRole ?? MemberFields.roleMember,
          autoOpenAddSheet: true,
        ),
      ),
    ).then((_) => _loadUserRole());
  }

  Future<void> _loadUserRole() async {
    final role = await _communityService.getUserRole(widget.communityId);
    if (mounted) {
      setState(() {
        _userRole = role;
        _isLoadingRole = false;
      });
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    final l10n = AppLocalizations.of(context)!;
    if (difference.inMinutes < 1) return l10n.timeNow;
    if (difference.inMinutes < 60) {
      return l10n.timeMinutesAgoShort(difference.inMinutes);
    }
    if (difference.inHours < 24) {
      return l10n.timeHoursAgoShort(difference.inHours);
    }
    if (difference.inDays == 1) return l10n.timeYesterday;
    return l10n.timeDaysAgoShort(difference.inDays);
  }

  bool get _isOfficial => _userRole == 'official';

  String _formatExactTime(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dateTime.day)}/${two(dateTime.month)}/${dateTime.year} ${two(dateTime.hour)}:${two(dateTime.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isSmall = sw < 360;

    final canAddMembers =
        !widget.isEntity && _userRole == MemberFields.roleAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.communityName,
              style: TextStyle(
                fontSize: isSmall ? 15 : 17,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C1C1E),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              widget.isEntity
                  ? AppLocalizations.of(context)!.officialEntity
                  : AppLocalizations.of(context)!.communityLabel,
              style: TextStyle(
                fontSize: isSmall ? 11 : 13,
                fontWeight: FontWeight.w400,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: isSmall ? 18 : 20,
            color: const Color(0xFF007AFF),
          ),
        ),
        actions: [
          if (canAddMembers)
            IconButton(
              tooltip: AppLocalizations.of(context)!.quickAddMember,
              icon: Icon(
                Icons.person_add_alt_1_rounded,
                size: isSmall ? 21 : 23,
                color: const Color(0xFF007AFF),
              ),
              onPressed: _openAddMembers,
            ),
          if (!widget.isEntity && !_isLoadingRole)
            IconButton(
              icon: Icon(
                Icons.settings_rounded,
                size: isSmall ? 20 : 22,
                color: const Color(0xFF007AFF),
              ),
              onPressed: () {
                Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunitySettingsView(
                      communityId: widget.communityId,
                      userRole: _userRole ?? 'member',
                    ),
                  ),
                ).then((leftCommunity) {
                  if (!mounted) return;
                  if (leftCommunity == true) {
                    if (!context.mounted) return;
                    Navigator.pop(context, true);
                  } else {
                    _loadUserRole();
                  }
                });
              },
            ),
        ],
      ),
      body: StreamBuilder<List<AlertModel>>(
        stream: _alertService.getCommunityAlertsStream(widget.communityId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF1F2937),
              ),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          final alerts = snapshot.data ?? [];
          final alertsNewestFirst = [...alerts]
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (alertsNewestFirst.isEmpty) {
            return _buildEmptyState();
          }

          _fadeController.forward(from: 0);

          return FadeTransition(
            opacity: _fadeAnimation,
            child: RefreshIndicator(
              onRefresh: () async => setState(() {}),
              color: const Color(0xFF007AFF),
              child: ListView.builder(
                reverse: true,
                padding: EdgeInsets.fromLTRB(
                  isSmall ? 8 : 12,
                  40,
                  isSmall ? 8 : 12,
                  12,
                ),
                itemCount: alertsNewestFirst.length,
                itemBuilder: (context, index) =>
                    _buildBubble(alertsNewestFirst[index], sw),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Chat Bubble ───────────────────────────────────────────────────────────

  Widget _buildBubble(AlertModel alert, double sw) {
    final l10n = AppLocalizations.of(context)!;
    final isOwn = _userService.isUserOwnerOfAlert(alert.userId, alert.userEmail);
    final alertColor = EmergencyTypes.getColor(alert.alertType);
    final alertIcon = EmergencyTypes.getIcon(alert.alertType);
    final timeAgo = _getTimeAgo(alert.timestamp);
    final isSmall = sw < 360;
    final headline = AlertSubtypeDisplay.primaryWithSubtypeLine(
          context,
          alert.alertType,
          alert.subtype,
          alert.customDetail) ??
        EmergencyTypes.getTranslatedType(alert.alertType, context);
    final subline = AlertSubtypeDisplay.line(
            context, alert.alertType, alert.subtype, alert.customDetail)
        .isNotEmpty
        ? EmergencyTypes.getTranslatedType(alert.alertType, context)
        : null;

    // Burbujas grandes para mostrar TODO el contenido sin recortes
    final maxBubbleWidth = (sw * (isSmall ? 0.90 : 0.86)).clamp(220.0, 560.0);

    final bubbleColor = isOwn
        ? const Color(0xFFDCEFFE) // azul clarito propio
        : Colors.white;

    final bubbleBorderRadius = isOwn
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );

    return Padding(
      padding: EdgeInsets.only(bottom: isSmall ? 10 : 14),
      child: Row(
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn) _buildAvatar(alertColor, alertIcon, isOwn: false),
          SizedBox(width: isSmall ? 4 : 8),

          // Burbuja
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDetailDialog(alert: alert),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: bubbleBorderRadius,
                    border: isOwn
                        ? Border.all(
                            color:
                                const Color(0xFF007AFF).withValues(alpha: 0.25),
                          )
                        : Border.all(
                            color: Colors.grey.withValues(alpha: 0.18),
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(isSmall ? 13 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 10 : 12,
                        vertical: isSmall ? 7 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: alert.isAnonymous
                            ? Colors.orange.withValues(alpha: 0.12)
                            : const Color(0xFF34C759).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: alert.isAnonymous
                              ? Colors.orange.withValues(alpha: 0.35)
                              : const Color(0xFF34C759).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            alert.isAnonymous
                                ? Icons.visibility_off_rounded
                                : Icons.verified_user_rounded,
                            size: isSmall ? 16 : 18,
                            color: alert.isAnonymous
                                ? Colors.orange.shade800
                                : const Color(0xFF248A3D),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alert.isAnonymous
                                  ? l10n.anonymous
                                  : l10n.identifiedAlert,
                              style: TextStyle(
                                fontSize: isSmall ? 12.5 : 13,
                                fontWeight: FontWeight.w700,
                                color: alert.isAnonymous
                                    ? Colors.orange.shade900
                                    : const Color(0xFF1C1C1E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmall ? 10 : 12),
                    Text(
                      widget.communityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmall ? 11 : 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                    SizedBox(height: isSmall ? 6 : 8),
                    Row(
                      children: [
                        Container(
                          width: isSmall ? 36 : 42,
                          height: isSmall ? 36 : 42,
                          decoration: BoxDecoration(
                            color: alertColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(alertIcon,
                              color: alertColor, size: isSmall ? 18 : 21),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headline,
                                style: TextStyle(
                                  fontSize: isSmall ? 14 : 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1C1C1E),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subline != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subline,
                                  style: TextStyle(
                                    fontSize: isSmall ? 12 : 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontSize: isSmall ? 11 : 12,
                                  color: Colors.grey[450],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.grey[350],
                            size: isSmall ? 18 : 20),
                      ],
                    ),

                    // ── Description ────────────────────────────────
                    if (alert.description != null &&
                        alert.description!.isNotEmpty) ...[
                      SizedBox(height: isSmall ? 8 : 10),
                      Text(
                        alert.description!,
                        style: TextStyle(
                          fontSize: isSmall ? 13 : 14.5,
                          color: Colors.grey[750],
                          height: 1.4,
                        ),
                        softWrap: true,
                      ),
                    ],

                    SizedBox(height: isSmall ? 8 : 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildChip(
                          icon: Icons.access_time_rounded,
                          label: _formatExactTime(alert.timestamp),
                          color: const Color(0xFF007AFF),
                          isSmall: isSmall,
                          maxLabelWidth: sw * 0.5,
                        ),
                        _buildChip(
                          icon: Icons.visibility_rounded,
                          label: '${l10n.viewCount}: ${alert.viewedCount}',
                          color: const Color(0xFF5AC8FA),
                          isSmall: isSmall,
                          maxLabelWidth: sw * 0.42,
                        ),
                        _buildChip(
                          icon: Icons.person_rounded,
                          label: alert.isAnonymous
                              ? l10n.anonymous
                              : (alert.userName?.trim().isNotEmpty == true
                                  ? alert.userName!
                                  : l10n.unknownUser),
                          color: const Color(0xFF1C1C1E),
                          isSmall: isSmall,
                          maxLabelWidth: sw * 0.48,
                        ),
                      ],
                    ),

                    if (alert.shareLocation && alert.location != null) ...[
                      SizedBox(height: isSmall ? 10 : 12),
                      _buildMiniMapPreview(alert, isSmall),
                    ],

                    SizedBox(height: isSmall ? 10 : 12),

                    // ── Chips row ──────────────────────────────────
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        if (alert.shareLocation && alert.location != null)
                          _buildChip(
                            icon: Icons.location_on_rounded,
                            label: l10n.locationShared,
                            color: const Color(0xFF34C759),
                            isSmall: isSmall,
                            maxLabelWidth: sw * 0.4,
                          ),
                        _buildStatusBadge(alert, isSmall),
                        if (alert.forwardsCount > 0)
                          _buildChip(
                            icon: Icons.reply_rounded,
                            label: '${alert.forwardsCount}',
                            color: const Color(0xFF007AFF),
                            isSmall: isSmall,
                          ),
                      ],
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SizedBox(width: isSmall ? 4 : 8),
          if (isOwn) _buildAvatar(alertColor, alertIcon, isOwn: true),
        ],
      ),
    );
  }

  Widget _buildAvatar(Color alertColor, IconData alertIcon,
      {required bool isOwn}) {
    final sw = MediaQuery.of(context).size.width;
    final size = sw < 360 ? 30.0 : 34.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOwn
              ? [
                  const Color(0xFF007AFF).withValues(alpha: 0.85),
                  const Color(0xFF007AFF).withValues(alpha: 0.55),
                ]
              : [
                  alertColor.withValues(alpha: 0.75),
                  alertColor.withValues(alpha: 0.45),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isOwn ? Icons.person_rounded : alertIcon,
        size: size * 0.48,
        color: Colors.white,
      ),
    );
  }

  // ─── Status Badge ──────────────────────────────────────────────────────────

  Widget _buildStatusBadge(AlertModel alert, bool isSmall) {
    final l10n = AppLocalizations.of(context)!;
    final isPending = alert.alertStatus == 'pending';
    final color = isPending ? const Color(0xFFFF9500) : const Color(0xFF34C759);
    final label = isPending
        ? l10n.alertStatusPendingShort
        : l10n.alertStatusAttendedShort;
    final icon =
        isPending ? Icons.schedule_rounded : Icons.check_circle_rounded;

    final chip = _buildChip(
        icon: icon, label: label, color: color, isSmall: isSmall);

    if (_isOfficial && alert.id != null) {
      return GestureDetector(
        onTap: () => _showStatusSheet(alert),
        child: chip,
      );
    }
    return chip;
  }

  void _showStatusSheet(AlertModel alert) {
    final sw = MediaQuery.of(context).size.width;
    final isSmall = sw < 360;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          isSmall ? 16 : 20,
          14,
          isSmall ? 16 : 20,
          32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.changeAlertStatusTitle,
              style: TextStyle(
                fontSize: isSmall ? 15 : 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.onlyOfficialsCanChangeStatus,
              style: TextStyle(
                  fontSize: isSmall ? 12 : 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 18),
            _buildStatusOption(
              alert: alert,
              status: 'pending',
              label: AppLocalizations.of(context)!.alertStatusPendingShort,
              icon: Icons.schedule_rounded,
              color: const Color(0xFFFF9500),
              isSelected: alert.alertStatus == 'pending',
              isSmall: isSmall,
            ),
            const SizedBox(height: 10),
            _buildStatusOption(
              alert: alert,
              status: 'attended',
              label: AppLocalizations.of(context)!.alertStatusAttendedShort,
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF34C759),
              isSelected: alert.alertStatus == 'attended',
              isSmall: isSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption({
    required AlertModel alert,
    required String status,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required bool isSmall,
  }) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        try {
          await _alertService.updateAlertStatus(alert.id!, status);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${AppLocalizations.of(context)!.errorUpdatingAlertStatus}: $e'),
              backgroundColor: Colors.red,
            ));
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 12 : 16,
          vertical: isSmall ? 11 : 14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.10)
              : const Color(0xFFF8F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: isSmall ? 32 : 36,
              height: isSmall ? 32 : 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: color, size: isSmall ? 16 : 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isSmall ? 14 : 15,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : const Color(0xFF1C1C1E),
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded,
                  color: color, size: isSmall ? 18 : 20),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSmall,
    double? maxLabelWidth,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (maxLabelWidth ?? 200) + (isSmall ? 36 : 40),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 7 : 9,
          vertical: isSmall ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isSmall ? 12 : 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSmall ? 11 : 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMapPreview(AlertModel alert, bool isSmall) {
    final lat = alert.location!.latitude;
    final lng = alert.location!.longitude;
    final alertColor = EmergencyTypes.getColor(alert.alertType);
    final alertIcon = EmergencyTypes.getIcon(alert.alertType);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: isSmall ? 105 : 120,
          width: double.infinity,
          child: Stack(
            children: [
              IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 15.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.guardian',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lng),
                          width: 28,
                          height: 28,
                          child: Container(
                            decoration: BoxDecoration(
                              color: alertColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(alertIcon, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.locationShared,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty / Error States ──────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 34, color: Color(0xFFFF3B30)),
            ),
            const SizedBox(height: 18),
            Text(
              AppLocalizations.of(context)!.alertsLoadErrorFeed,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.checkConnectionRetry,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(AppLocalizations.of(context)!.retry),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF007AFF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.notifications_none_rounded,
                  size: 36, color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.communityFeedEmptyTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context)!.communityFeedEmptySubtitle,
              style:
                  TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
