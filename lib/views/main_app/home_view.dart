import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guardian/core/app_logger.dart';
import 'package:guardian/views/main_app/widgets/alert_button.dart';
import 'package:guardian/handlers/home_handler.dart';
import 'package:guardian/models/alert_model.dart';
import 'package:guardian/views/main_app/widgets/alert_detail_dialog.dart';
import 'package:guardian/views/main_app/settings_view.dart';
import 'package:guardian/services/localization_service.dart';
import 'package:guardian/services/user_service.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final HomeHandler _homeHandler = HomeHandler();
  final UserService _userService = UserService();
  List<AlertModel> _recentAlerts = [];
  bool _isLoading = true;
  /// true = modo UP (mis alertas enviadas), false = modo DOWN (recibidas)
  bool _showingOwn = false;

  /// Lista filtrada según el toggle Up/Down
  List<AlertModel> get _filteredAlerts {
    if (_showingOwn) {
      return _recentAlerts
          .where((a) => _userService.isUserOwnerOfAlert(a.userId, a.userEmail))
          .toList();
    } else {
      return _recentAlerts
          .where((a) => !_userService.isUserOwnerOfAlert(a.userId, a.userEmail))
          .toList();
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeController();
    _checkServiceStatus();
    
    // Refrescar el estado del servicio cada 2 segundos para sincronización
    _startServiceStatusRefresh();
  }

  void _startServiceStatusRefresh() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkServiceStatus();
        _startServiceStatusRefresh(); // Continuar refrescando
      }
    });
  }

  Future<void> _initializeController() async {
    // Configurar callbacks
    _homeHandler.onAlertsUpdated = (alerts) {
      setState(() {
        _recentAlerts = alerts;
        _isLoading = false;
      });
    };

    _homeHandler.onNewAlertReceived = (alert) {
      // Mostrar un snackbar adicional para alertas nuevas
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${AppLocalizations.of(context)!.alertNotification}: ${EmergencyTypes.getTranslatedType(alert.alertType, context)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.viewAction,
              textColor: Colors.white,
              onPressed: () {
                _showAlertDetail(alert);
              },
            ),
          ),
        );
      }
    };

    try {
      await _homeHandler.initialize();
      await _homeHandler.refreshRecentAlerts();
    } catch (e) {
      AppLogger.e('HomeView._initializeController', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.alertsLoadError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _checkServiceStatus() async {
    try {
      final isRunning = await _homeHandler.isServiceRunning();
      AppLogger.d('Background service running: $isRunning');
    } catch (e) {
      AppLogger.e('HomeView._checkServiceStatus', e);
    }
  }

  // Método para refrescar el estado del servicio desde otros lugares
  Future<void> refreshServiceStatus() async {
    await _checkServiceStatus();
  }

  @override
  void dispose() {
    // NO llamar dispose aquí - el controlador debe permanecer activo
    // Solo se limpia cuando la app se cierra completamente
    super.dispose();
  }

  /// Altura del bloque "Alertas recientes": compacto; cabe cabecera + ~1 tarjeta
  /// densa y el resto con scroll. Libera espacio para el botón de emergencia.
  double _recentAlertsPanelHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final w = MediaQuery.sizeOf(context).width;
    final fraction = w < 360
        ? 0.24
        : w < 420
            ? 0.21
            : w < 600
                ? 0.18
                : 0.16;
    final desiredMin = w < 360
        ? 156.0
        : w < 420
            ? 150.0
            : 144.0;
    if (h < 520) {
      final cap = h * 0.32;
      return math.min(cap, math.max(140.0, h * fraction));
    }
    final maxPanel = math.min(232.0, h * 0.28);
    final minPanel = math.min(desiredMin, maxPanel);
    return (h * fraction).clamp(minPanel, maxPanel);
  }

  @override
  Widget build(BuildContext context) {
    final alertsPanelHeight = _recentAlertsPanelHeight(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Sección de alertas recientes con altura adaptativa
            SizedBox(
              height: alertsPanelHeight,
              child: _buildRecentAlertsSection(panelHeight: alertsPanelHeight),
            ),

            // Área principal del botón de alerta — gets all remaining space
            Expanded(
              child: _buildAlertButtonSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    final headerPadding = isSmall
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 14)
        : const EdgeInsets.all(20);
    final titleFontSize = (screenWidth * 0.068).clamp(20.0, 28.0);
    final subtitleFontSize = isSmall ? 12.0 : 14.0;
    final buttonSize = isSmall ? 40.0 : 48.0;
    final iconSize = isSmall ? 20.0 : 24.0;
    final spacing = isSmall ? 8.0 : 12.0;

    return Container(
      padding: headerPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo y título
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.appTitle,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                    letterSpacing: isSmall ? 0.8 : 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context)!.safetyPriority,
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Botón de notificaciones
          _buildHeaderButton(
            icon: Icons.notifications_outlined,
            iconSize: iconSize,
            buttonSize: buttonSize,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${AppLocalizations.of(context)!.notifications} - ${AppLocalizations.of(context)!.comingSoon}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          SizedBox(width: spacing),

          // Botón de idioma
          _buildLanguageButton(buttonSize: buttonSize),

          SizedBox(width: spacing),

          // Botón de configuración
          _buildHeaderButton(
            icon: Icons.settings_outlined,
            iconSize: iconSize,
            buttonSize: buttonSize,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsView(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onPressed,
    double iconSize = 24,
    double buttonSize = 48,
  }) {
    return Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF1A1A1A)),
        iconSize: iconSize,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildRecentAlertsSection({required double panelHeight}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    // Panel siempre “denso”: tipografía pequeña y tarjetas bajas; scroll para el resto.
    final isCompact = true;
    final dense = panelHeight < 255;
    final horizontalInset = isSmall ? 10.0 : 16.0;
    final verticalInset = dense ? 6.0 : (isSmall ? 8.0 : 12.0);
    final sectionPaddingH = isSmall ? 10.0 : 14.0;
    final sectionPaddingV = dense ? 8.0 : 10.0;
    final titleFontSize = isSmall ? 13.0 : 14.0;
    final iconSize = isSmall ? 15.0 : 17.0;
    final filtered = _filteredAlerts;

    return Container(
      margin: EdgeInsets.fromLTRB(
        horizontalInset,
        verticalInset,
        horizontalInset,
        verticalInset,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: sectionPaddingH,
        vertical: sectionPaddingV,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmall ? 5 : 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: const Color(0xFF1976D2),
                  size: iconSize,
                ),
              ),
              SizedBox(width: isSmall ? 6 : 10),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.recentAlerts,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Count badge
              if (filtered.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filtered.length}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                SizedBox(width: isSmall ? 6 : 8),
              ],
              // ── Up/Down toggle ──────────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _showingOwn = !_showingOwn),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 7 : 9,
                    vertical: isSmall ? 5 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: _showingOwn
                        ? const Color(0xFF007AFF).withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _showingOwn
                          ? const Color(0xFF007AFF).withValues(alpha: 0.35)
                          : Colors.grey.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _showingOwn
                              ? Icons.arrow_circle_up_rounded
                              : Icons.arrow_circle_down_rounded,
                          key: ValueKey(_showingOwn),
                          size: isSmall ? 16 : 18,
                          color: _showingOwn
                              ? const Color(0xFF007AFF)
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: dense ? 6 : 8),

          Expanded(
            child: _isLoading
                ? _buildLoadingState(compact: isCompact, dense: dense)
                : filtered.isEmpty
                    ? _buildNoAlertsState(compact: isCompact, dense: dense)
                    : _buildAlertsList(filtered, compact: isCompact, dense: dense),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState({bool compact = false, bool dense = false}) {
    return Container(
      padding: EdgeInsets.all(dense ? 10 : (compact ? 12 : 24)),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          SizedBox(
            width: dense ? 16 : 20,
            height: dense ? 16 : 20,
            child: CircularProgressIndicator(strokeWidth: dense ? 1.75 : 2),
          ),
          SizedBox(width: dense ? 8 : 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.loading,
              style: TextStyle(
                fontSize: dense ? 11.5 : (compact ? 12.5 : 14),
                color: const Color(0xFF6B7280),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAlertsState({bool compact = false, bool dense = false}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 6 : (compact ? 8 : 12),
          vertical: dense ? 2 : (compact ? 4 : 6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: dense ? 18 : (compact ? 20 : 24),
              color: Colors.grey[400],
            ),
            SizedBox(width: dense ? 8 : 10),
            Flexible(
              child: Text(
                _showingOwn
                    ? 'No has enviado alertas recientes'
                    : AppLocalizations.of(context)!.noRecentAlerts,
                style: TextStyle(
                  fontSize: dense ? 11 : (compact ? 11.5 : 13),
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsList(List<AlertModel> alerts, {bool compact = false, bool dense = false}) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoading = true);
        try {
          await _homeHandler.refreshRecentAlerts();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.alertsUpdateError),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        if (mounted) setState(() => _isLoading = false);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return TweenAnimationBuilder<double>(
            key: ValueKey(alert.id ?? index),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 200 + (index * 50).clamp(0, 300)),
            curve: Curves.easeOut,
            builder: (context, value, child) => Opacity(opacity: value, child: child),
            child: _buildAlertCard(alert, compact: compact, dense: dense),
          );
        },
      ),
    );
  }

  void _showAlertDetail(AlertModel alert) {
    // Mostrar el detalle de la alerta en un diálogo
    showDialog(
      context: context,
      builder: (context) => AlertDetailDialog(alert: alert),
    );
  }



  Widget _buildAlertCard(AlertModel alert, {bool compact = false, bool dense = false}) {
    final alertIcon = EmergencyTypes.getIcon(alert.alertType);
    final alertColor = EmergencyTypes.getColor(alert.alertType);
    final timeAgo = _getTimeAgo(alert.timestamp);
    final isAttended = alert.alertStatus == 'attended';
    final statusColor =
        isAttended ? const Color(0xFF34C759) : const Color(0xFFFF9F0A);

    final iconBox = dense ? 5.0 : (compact ? 6.0 : 8.0);
    final iconGraphic = dense ? 16.0 : (compact ? 17.5 : 20.0);
    final gap = dense ? 6.0 : (compact ? 8.0 : 12.0);
    final titleSize = dense ? 11.5 : (compact ? 12.5 : 14.0);
    final descSize = dense ? 10.5 : (compact ? 11.5 : 13.0);
    final cardPad = dense ? 7.0 : (compact ? 9.0 : 16.0);
    final bottomMargin = dense ? 6.0 : (compact ? 7.0 : 12.0);

    Widget statusBadge() {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 4 : (compact ? 5 : 6),
          vertical: dense ? 1.5 : (compact ? 2 : 3),
        ),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAttended ? Icons.check_circle_rounded : Icons.schedule_rounded,
              size: dense ? 8 : (compact ? 9 : 10),
              color: statusColor,
            ),
            SizedBox(width: dense ? 2 : (compact ? 2 : 3)),
            Text(
              isAttended ? 'Atendida' : 'No atendida',
              style: TextStyle(
                fontSize: dense ? 8 : (compact ? 9 : 10),
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ],
        ),
      );
    }

    final metaChips = <Widget>[
      if (alert.shareLocation && alert.location != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            AppLocalizations.of(context)!.locationTag,
            style: TextStyle(
              fontSize: dense ? 8 : (compact ? 9 : 10),
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      if (alert.isAnonymous)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            AppLocalizations.of(context)!.anonymousTag,
            style: TextStyle(
              fontSize: dense ? 8 : (compact ? 9 : 10),
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      if (alert.viewedCount > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '👁️ ${alert.viewedCount}',
            style: TextStyle(
              fontSize: dense ? 8 : (compact ? 9 : 10),
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      if (alert.forwardsCount > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forward, size: dense ? 8 : (compact ? 9 : 10), color: Colors.blue[700]),
              const SizedBox(width: 2),
              Text(
                '${alert.forwardsCount}',
                style: TextStyle(
                  fontSize: dense ? 8 : (compact ? 9 : 10),
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      if (alert.reportsCount > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.report, size: dense ? 8 : (compact ? 9 : 10), color: Colors.orange[700]),
              const SizedBox(width: 2),
              Text(
                '${alert.reportsCount}',
                style: TextStyle(
                  fontSize: dense ? 8 : (compact ? 9 : 10),
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          alert.type.toUpperCase(),
          style: TextStyle(
            fontSize: dense ? 8 : (compact ? 9 : 10),
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    ];

    return GestureDetector(
      onTap: () => _showAlertDetail(alert),
      child: Container(
        margin: EdgeInsets.only(bottom: bottomMargin),
        padding: EdgeInsets.all(cardPad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(dense ? 10 : 12),
          border: Border.all(color: alertColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: alertColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(iconBox),
              decoration: BoxDecoration(
                color: alertColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                alertIcon,
                color: alertColor,
                size: iconGraphic,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (compact) ...[
                    Text(
                      alert.alertType,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: dense ? 3 : (compact ? 4 : 6)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(child: statusBadge()),
                        SizedBox(width: dense ? 6 : 8),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: dense ? 10 : (compact ? 11 : 12),
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            alert.alertType,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1A1A),
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        statusBadge(),
                        const SizedBox(width: 6),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (alert.description != null &&
                      alert.description!.isNotEmpty) ...[
                    SizedBox(height: dense ? 3 : (compact ? 4 : 6)),
                    Text(
                      alert.description!,
                      style: TextStyle(
                        fontSize: descSize,
                        color: Colors.grey[600],
                        height: dense ? 1.15 : 1.25,
                      ),
                      maxLines: dense ? 1 : (compact ? 1 : 2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: dense ? 4 : (compact ? 6 : 8)),
                  Wrap(
                    spacing: dense ? 4 : 6,
                    runSpacing: dense ? 3 : 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: metaChips,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    final l10n = AppLocalizations.of(context)!;

    if (difference.inMinutes < 1) return l10n.timeNow;
    if (difference.inMinutes < 60) return l10n.timeMinutesAgo(difference.inMinutes);
    if (difference.inHours < 24) return l10n.timeHoursAgo(difference.inHours);
    if (difference.inDays == 1) return l10n.timeYesterday;
    return l10n.timeDaysAgo(difference.inDays);
  }

  Widget _buildAlertButtonSection() {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.sizeOf(context).height;
    final isSmall = sw < 360;
    final isLargePhone = sw >= 420 && sh >= 720;
    // Más aire alrededor del radial; el Expanded ya recibe más alto al achicar alertas.
    final titleSize = isSmall
        ? (sw * 0.048).clamp(15.0, 17.0)
        : isLargePhone
            ? (sw * 0.052).clamp(18.0, 24.0)
            : (sw * 0.05).clamp(16.0, 21.0);

    return Container(
      padding: EdgeInsets.fromLTRB(
        isSmall ? 10 : 14,
        isSmall ? 10 : (isLargePhone ? 16 : 12),
        isSmall ? 10 : 14,
        isSmall ? 8 : (isLargePhone ? 14 : 10),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: isSmall ? 8 : (isLargePhone ? 14 : 10),
              top: isSmall ? 2 : 4,
            ),
            child: Text(
              AppLocalizations.of(context)!.emergencyButton,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
                height: 1.2,
                letterSpacing: isLargePhone ? 0.2 : 0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // AlertButton fills all remaining vertical space
          Expanded(
            child: AlertButton(
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  // Método para construir el botón de idioma
  Widget _buildLanguageButton({double buttonSize = 48}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE9ECEF),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showLanguageDialog(context),
          child: SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: Center(
              child: Consumer<LocalizationService>(
                builder: (context, localizationService, child) {
                  return Text(
                    localizationService.currentFlag,
                    style: TextStyle(fontSize: buttonSize < 44 ? 17 : 20),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Método para mostrar el diálogo de selección de idioma
  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.selectLanguage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Text('🇪🇸', style: TextStyle(fontSize: 24)),
                title: Text(AppLocalizations.of(context)!.spanish),
                onTap: () {
                  context.read<LocalizationService>().setLanguage(const Locale('es'));
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
                title: Text(AppLocalizations.of(context)!.english),
                onTap: () {
                  context.read<LocalizationService>().setLanguage(const Locale('en'));
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

}
