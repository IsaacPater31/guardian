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

class _CommunityFeedViewState extends State<CommunityFeedView> {
  final AlertRepository _alertRepository = AlertRepository();
  final CommunityService _communityService = CommunityService();
  String? _userRole;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _communityService.getUserRole(widget.communityId);
    setState(() {
      _userRole = role;
      _isLoadingRole = false;
    });
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
      appBar: AppBar(
        title: Text(widget.communityName),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!widget.isEntity && !_isLoadingRole)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunitySettingsView(
                      communityId: widget.communityId,
                      userRole: _userRole ?? 'member',
                    ),
                  ),
                ).then((_) {
                  // Recargar rol después de volver (por si cambió)
                  _loadUserRole();
                });
              },
            ),
        ],
      ),
      body: StreamBuilder<List<AlertModel>>(
        stream: _alertRepository.getCommunityAlertsStream(widget.communityId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.alertsLoadErrorFeed,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.checkConnectionRetry,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                      label: Text(AppLocalizations.of(context)!.retry),
                    ),
                  ],
                ),
              ),
            );
          }

          final alerts = snapshot.data ?? [];

          // Validar si no hay alertas en esta comunidad
          if (alerts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No hay alertas en esta comunidad',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Las alertas aparecerán aquí cuando se envíen a esta comunidad',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return _buildAlertCard(alert);
              },
            ),
          );
        },
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: alertColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: alertColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icono de alerta
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: alertColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    alertIcon,
                    color: alertColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Tipo de alerta y tiempo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.alertType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (alert.description != null && alert.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                alert.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Información adicional
            Row(
              children: [
                if (alert.shareLocation && alert.location != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Ubicación',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (alert.forwardsCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.forward, size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          '${alert.forwardsCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (alert.reportsCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.report, size: 14, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text(
                          '${alert.reportsCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
