import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guardian/views/main_app/widgets/alert_button.dart';
import 'package:guardian/controllers/main_app/home_controller.dart';
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
  final HomeController _homeController = HomeController();
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
    _homeController.onAlertsUpdated = (alerts) {
      setState(() {
        _recentAlerts = alerts;
        _isLoading = false;
      });
    };

    _homeController.onNewAlertReceived = (alert) {
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
                    '${AppLocalizations.of(context)!.alertNotification}: ${alert.alertType}',
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
      await _homeController.initialize();
      await _homeController.refreshRecentAlerts();
    } catch (e) {
      print('Error inicializando Home: $e');
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
      final isRunning = await _homeController.isServiceRunning();
      print('🔍 Background service status: $isRunning');
    } catch (e) {
      print('❌ Error checking service status: $e');
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    // Alerts panel: give it less space on compact screens so the radial
    // button has room for 8 labels + central circle without clipping.
    final alertsFraction = screenWidth < 360
        ? 0.18
        : screenWidth < 400
            ? 0.22
            : 0.26;
    final alertsPanelHeight = (screenHeight * alertsFraction).clamp(130.0, 260.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Sección de alertas recientes con altura adaptativa
            SizedBox(
              height: alertsPanelHeight,
              child: _buildRecentAlertsSection(),
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

  Widget _buildRecentAlertsSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    final sectionPadding = isSmall ? 14.0 : 20.0;
    final titleFontSize = isSmall ? 15.0 : 18.0;
    final iconSize = isSmall ? 17.0 : 20.0;
    final filtered = _filteredAlerts;

    return Container(
      margin: EdgeInsets.all(sectionPadding),
      padding: EdgeInsets.all(sectionPadding),
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
                padding: EdgeInsets.all(isSmall ? 6 : 8),
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
                      fontSize: 12,
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
                    horizontal: isSmall ? 8 : 11,
                    vertical: isSmall ? 6 : 7,
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
                          size: isSmall ? 18 : 20,
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

          SizedBox(height: isSmall ? 10 : 16),

          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : filtered.isEmpty
                    ? _buildNoAlertsState()
                    : _buildAlertsList(filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            AppLocalizations.of(context)!.loading,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAlertsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 24,
              color: Colors.grey[400],
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _showingOwn
                    ? 'No has enviado alertas recientes'
                    : AppLocalizations.of(context)!.noRecentAlerts,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsList(List<AlertModel> alerts) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoading = true);
        try {
          await _homeController.refreshRecentAlerts();
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
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return TweenAnimationBuilder<double>(
            key: ValueKey(alert.id ?? index),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 200 + (index * 50).clamp(0, 300)),
            curve: Curves.easeOut,
            builder: (context, value, child) => Opacity(opacity: value, child: child),
            child: _buildAlertCard(alert),
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
        child: Row(
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
            
            // Contenido de la alerta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.alertType,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  
                  if (alert.description != null && alert.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      alert.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  const SizedBox(height: 8),
                  
                  // Información adicional
                  Row(
                    children: [
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
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      
                      if (alert.isAnonymous) ...[
                        if (alert.shareLocation && alert.location != null)
                          const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.anonymousTag,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],

                      // Contador de vistas
                      if (alert.viewedCount > 0) ...[
                        if (alert.shareLocation && alert.location != null || alert.isAnonymous)
                          const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '👁️ ${alert.viewedCount}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      if (alert.forwardsCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.forward, size: 10, color: Colors.blue[700]),
                              const SizedBox(width: 2),
                              Text(
                                '${alert.forwardsCount}',
                                style: TextStyle(fontSize: 10, color: Colors.blue[700], fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (alert.reportsCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.report, size: 10, color: Colors.orange[700]),
                              const SizedBox(width: 2),
                              Text(
                                '${alert.reportsCount}',
                                style: TextStyle(fontSize: 10, color: Colors.orange[700], fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const Spacer(),
                      
                      Text(
                        alert.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
    final isSmall = sw < 360;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isSmall ? 4 : 12,
        isSmall ? 2 : 6,
        isSmall ? 4 : 12,
        isSmall ? 2 : 4,
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: isSmall ? 1 : 2),
            child: Text(
              AppLocalizations.of(context)!.emergencyButton,
              style: TextStyle(
                fontSize: (sw * 0.042).clamp(13.0, 19.0),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
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
