import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guardian/views/main_app/widgets/alert_button.dart';
import 'package:guardian/controllers/main_app/home_controller.dart';
import 'package:guardian/models/alert_model.dart';
import 'package:guardian/views/main_app/widgets/alert_detail_dialog.dart';
import 'package:guardian/views/main_app/settings_view.dart';
import 'package:guardian/services/localization_service.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final HomeController _homeController = HomeController();
  List<AlertModel> _recentAlerts = [];
  bool _isLoading = true;

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
              label: 'Ver',
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header elegante
            _buildHeader(),
            
            // Sección de alertas recientes con altura fija
            Container(
              height: 280, // Altura fija para respetar el círculo
              child: _buildRecentAlertsSection(),
            ),
            
            // Área principal del botón de alerta
            Expanded(
              child: _buildAlertButtonSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
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
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your safety is our priority',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Botón de notificaciones (sin funcionalidad por ahora)
          _buildHeaderButton(
            icon: Icons.notifications_outlined,
            onPressed: () {
              // Sin funcionalidad - se implementará más adelante
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.notifications + ' - Funcionalidad próximamente'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          
          const SizedBox(width: 12),
          
          // Botón de idioma
          _buildLanguageButton(),
          
          const SizedBox(width: 12),
          
          // Botón de configuración
          _buildHeaderButton(
            icon: Icons.settings_outlined,
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF1A1A1A)),
        iconSize: 24,
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildRecentAlertsSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
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
          // Título de la sección
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFF1976D2),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.recentAlerts,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              if (_recentAlerts.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_recentAlerts.length}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Estado de alertas con scroll
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _recentAlerts.isEmpty
                    ? _buildNoAlertsState()
                    : _buildAlertsList(),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.noRecentAlerts,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Everything is quiet in your area',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList() {
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
        itemCount: _recentAlerts.length,
        itemBuilder: (context, index) {
          final alert = _recentAlerts[index];
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
                          child: const Text(
                            '📍 Location',
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
                          child: const Text(
                            '👤 Anonymous',
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10), // Subir un poco más todo el bloque
      child: Column(
        children: [
          // Título de la sección
          Text(
            AppLocalizations.of(context)!.emergencyButton,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.dragForEmergencyTypes,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 6), // Aún menos espacio para subir el botón
          
          // Botón de alerta responsivo
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calcular dimensiones responsivas basadas en el tamaño de pantalla
                  final screenWidth = MediaQuery.of(context).size.width;
                  final screenHeight = MediaQuery.of(context).size.height;
                  
                  // Dimensiones base para diferentes tipos de pantalla
                  double containerWidth;
                  double containerHeight;
                  
                  if (screenWidth < 400) {
                    // Pantallas pequeñas (teléfonos compactos)
                    containerWidth = screenWidth * 0.9;
                    containerHeight = screenHeight * 0.4;
                  } else if (screenWidth < 600) {
                    // Pantallas medianas (teléfonos normales)
                    containerWidth = screenWidth * 0.85;
                    containerHeight = screenHeight * 0.45;
                  } else if (screenWidth < 900) {
                    // Pantallas grandes (tablets pequeñas)
                    containerWidth = screenWidth * 0.7;
                    containerHeight = screenHeight * 0.5;
                  } else {
                    // Pantallas muy grandes (tablets grandes)
                    containerWidth = screenWidth * 0.6;
                    containerHeight = screenHeight * 0.55;
                  }
                  
                  // Asegurar que no exceda las dimensiones disponibles
                  final minWidth = 200.0;
                  final minHeight = 200.0;
                  final maxWidth = constraints.maxWidth > minWidth ? constraints.maxWidth : minWidth;
                  final maxHeight = constraints.maxHeight > minHeight ? constraints.maxHeight : minHeight;
                  
                  containerWidth = containerWidth.clamp(minWidth, maxWidth);
                  containerHeight = containerHeight.clamp(minHeight, maxHeight);
                  
                  return SizedBox(
                    width: containerWidth,
                    height: containerHeight,
                    child: AlertButton(
                      onPressed: () {
                        // TODO: Implement general alert
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          
        ],
      ),
    );
  }

  // Método para construir el botón de idioma
  Widget _buildLanguageButton() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
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
          child: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(12),
            child: Consumer<LocalizationService>(
              builder: (context, localizationService, child) {
                return Text(
                  localizationService.currentFlag,
                  style: const TextStyle(fontSize: 20),
                  textAlign: TextAlign.center,
                );
              },
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