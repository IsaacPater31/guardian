import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/models/alert_model.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/services/alert_repository.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/services/user_service.dart';
import 'package:guardian/views/main_app/widgets/alert_detail_dialog.dart';
import 'package:guardian/views/main_app/community_settings_view.dart';

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
  final AlertRepository _alertRepository = AlertRepository();
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

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isSmall = sw < 360;

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
          if (!widget.isEntity && !_isLoadingRole)
            IconButton(
              icon: Icon(
                Icons.settings_rounded,
                size: isSmall ? 20 : 22,
                color: const Color(0xFF007AFF),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunitySettingsView(
                      communityId: widget.communityId,
                      userRole: _userRole ?? 'member',
                    ),
                  ),
                ).then((_) => _loadUserRole());
              },
            ),
        ],
      ),
      body: StreamBuilder<List<AlertModel>>(
        stream: _alertRepository.getCommunityAlertsStream(widget.communityId),
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

          if (alerts.isEmpty) {
            return _buildEmptyState();
          }

          _fadeController.forward(from: 0);

          return FadeTransition(
            opacity: _fadeAnimation,
            child: RefreshIndicator(
              onRefresh: () async => setState(() {}),
              color: const Color(0xFF007AFF),
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  isSmall ? 8 : 12,
                  12,
                  isSmall ? 8 : 12,
                  40,
                ),
                itemCount: alerts.length,
                itemBuilder: (context, index) =>
                    _buildBubble(alerts[index], sw),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Chat Bubble ───────────────────────────────────────────────────────────

  Widget _buildBubble(AlertModel alert, double sw) {
    final isOwn = _userService.isUserOwnerOfAlert(alert.userId, alert.userEmail);
    final alertColor = EmergencyTypes.getColor(alert.alertType);
    final alertIcon = EmergencyTypes.getIcon(alert.alertType);
    final timeAgo = _getTimeAgo(alert.timestamp);
    final isSmall = sw < 360;

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
                    // ── Header ─────────────────────────────────────
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
                                alert.alertType,
                                style: TextStyle(
                                  fontSize: isSmall ? 14 : 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1C1C1E),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.visible,
                              ),
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

                    SizedBox(height: isSmall ? 10 : 12),

                    // ── Chips row ──────────────────────────────────
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        if (alert.shareLocation && alert.location != null)
                          _buildChip(
                            icon: Icons.location_on_rounded,
                            label: 'Ubicación',
                            color: const Color(0xFF34C759),
                            isSmall: isSmall,
                          ),
                        if (alert.isAnonymous)
                          _buildChip(
                            icon: Icons.visibility_off_rounded,
                            label: 'Anónimo',
                            color: Colors.orange,
                            isSmall: isSmall,
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
    final isPending = alert.alertStatus == 'pending';
    final color = isPending ? const Color(0xFFFF9500) : const Color(0xFF34C759);
    final label = isPending ? 'Pendiente' : 'Atendida';
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
              'Cambiar estado',
              style: TextStyle(
                fontSize: isSmall ? 15 : 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Solo los oficiales pueden cambiar el estado.',
              style: TextStyle(
                  fontSize: isSmall ? 12 : 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 18),
            _buildStatusOption(
              alert: alert,
              status: 'pending',
              label: 'Pendiente',
              icon: Icons.schedule_rounded,
              color: const Color(0xFFFF9500),
              isSelected: alert.alertStatus == 'pending',
              isSmall: isSmall,
            ),
            const SizedBox(height: 10),
            _buildStatusOption(
              alert: alert,
              status: 'attended',
              label: 'Atendida',
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
          await _alertRepository.updateAlertStatus(alert.id!, status);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error actualizando estado: $e'),
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
  }) {
    return Container(
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
          Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 11 : 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
            const Text(
              'Sin alertas por ahora',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Las alertas de esta comunidad aparecerán aquí',
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
