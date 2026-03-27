import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/models/alert_model.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/services/alert_repository.dart';
import 'package:guardian/services/community_service.dart';
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
  String? _userRole;
  bool _isLoadingRole = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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
    if (difference.inMinutes < 60) return l10n.timeMinutesAgoShort(difference.inMinutes);
    if (difference.inHours < 24) return l10n.timeHoursAgoShort(difference.inHours);
    if (difference.inDays == 1) return l10n.timeYesterday;
    return l10n.timeDaysAgoShort(difference.inDays);
  }

  void _showAlertDetail(AlertModel alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDetailDialog(alert: alert),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              widget.isEntity ? AppLocalizations.of(context)!.officialEntity : AppLocalizations.of(context)!.communityLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xFF007AFF),
          ),
        ),
        actions: [
          if (!widget.isEntity && !_isLoadingRole)
            IconButton(
              icon: Icon(
                Icons.settings_rounded,
                size: 22,
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

          // Trigger fade animation
          _fadeController.forward(from: 0);

          return FadeTransition(
            opacity: _fadeAnimation,
            child: RefreshIndicator(
              onRefresh: () async => setState(() {}),
              color: const Color(0xFF007AFF),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: alerts.length,
                itemBuilder: (context, index) =>
                    _buildAlertCard(alerts[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: Color(0xFFFF3B30),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.alertsLoadErrorFeed,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.checkConnectionRetry,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => setState(() {}),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF007AFF),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                AppLocalizations.of(context)!.retry,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No hay alertas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Las alertas aparecerán aquí cuando se envíen a esta comunidad',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AlertModel alert) {
    final alertIcon = EmergencyTypes.getIcon(alert.alertType);
    final alertColor = EmergencyTypes.getColor(alert.alertType);
    final timeAgo = _getTimeAgo(alert.timestamp);

    return GestureDetector(
      onTap: () => _showAlertDetail(alert),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  // Alert icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          alertColor.withValues(alpha: 0.15),
                          alertColor.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      alertIcon,
                      color: alertColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Type and time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.alertType,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[350],
                    size: 22,
                  ),
                ],
              ),
            ),

            // Description
            if (alert.description != null &&
                alert.description!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(
                  alert.description!,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            // Tags
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  if (alert.shareLocation && alert.location != null)
                    _buildTag(
                      icon: Icons.location_on_rounded,
                      label: 'Ubicación',
                      color: const Color(0xFF34C759),
                    ),
                  const Spacer(),
                  if (alert.forwardsCount > 0) ...[
                    _buildTag(
                      icon: Icons.reply_rounded,
                      label: '${alert.forwardsCount}',
                      color: const Color(0xFF007AFF),
                    ),
                  ],
                  if (alert.reportsCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildTag(
                      icon: Icons.flag_rounded,
                      label: '${alert.reportsCount}',
                      color: const Color(0xFFFF9500),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
