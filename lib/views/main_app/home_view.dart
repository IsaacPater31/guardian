import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:guardian/views/main_app/widgets/alert_button.dart';
import 'package:guardian/controllers/main_app/home_controller.dart';
import 'package:guardian/models/alert_model.dart';
import 'package:guardian/views/main_app/widgets/alert_detail_dialog.dart';
import 'package:guardian/views/main_app/mapa_view.dart';
import 'package:guardian/services/background_service.dart';
import 'package:guardian/services/background/background_service_factory.dart';
import 'package:guardian/services/background_service_dialog_service.dart';
import 'package:guardian/services/native_background_service.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final HomeController _homeController = HomeController();
  final BackgroundService _backgroundService = BackgroundService();
  List<AlertModel> _recentAlerts = [];
  bool _isLoading = true;
  bool _isServiceRunning = false;
  bool _isServiceLoading = true;
  Map<String, dynamic> _platformCapabilities = {};

  @override
  void initState() {
    super.initState();
    _initializeController();
    _loadPlatformInfo();
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
                    'Nueva alerta: ${alert.alertType}',
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

    // Inicializar el controlador
    await _homeController.initialize();
  }

  Future<void> _loadPlatformInfo() async {
    _platformCapabilities = BackgroundServiceFactory.getPlatformCapabilities();
    setState(() {});
  }

  Future<void> _checkServiceStatus() async {
    try {
      await _backgroundService.initialize();
      final isRunning = await _backgroundService.isServiceRunning();
      print('🔍 Background service status: $isRunning');
      setState(() {
        _isServiceRunning = isRunning;
        _isServiceLoading = false;
      });
    } catch (e) {
      print('❌ Error checking service status: $e');
      setState(() {
        _isServiceLoading = false;
      });
    }
  }

  Future<void> _toggleBackgroundService() async {
    try {
      if (_isServiceRunning) {
        print('🛑 Stopping background service...');
        await _backgroundService.stopBackgroundMonitoring();
      } else {
        print('🚀 Starting background service...');
        await _backgroundService.startBackgroundMonitoring();
      }
      
      await _checkServiceStatus();
    } catch (e) {
      print('❌ Error toggling background service: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método para refrescar el estado del servicio desde otros lugares
  Future<void> refreshServiceStatus() async {
    await _checkServiceStatus();
  }



  @override
  void dispose() {
    _homeController.dispose();
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
                const Text(
                  'GUARDIAN',
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
          
          // Botones de acción
          Row(
            children: [
              _buildHeaderButton(
                icon: BackgroundServiceDialogService.getServiceIcon(
                  isServiceLoading: _isServiceLoading,
                  isServiceRunning: _isServiceRunning,
                ),
                onPressed: () {
                  BackgroundServiceDialogService.showServiceDialog(
                    context,
                    isServiceRunning: _isServiceRunning,
                    isServiceLoading: _isServiceLoading,
                    onToggleService: _toggleBackgroundService,
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildHeaderButton(
                icon: Icons.settings_outlined,
                onPressed: () {
                  // TODO: Implement settings
                },
              ),
            ],
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
              const Text(
                'Recent Alerts',
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
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Loading recent alerts...',
            style: TextStyle(
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
            'No alerts currently',
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
    return ListView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: _recentAlerts.length,
      itemBuilder: (context, index) {
        final alert = _recentAlerts[index];
        return _buildAlertCard(alert);
      },
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
    final alertIcon = _getAlertIcon(alert.alertType);
    final alertColor = _getAlertColor(alert.alertType);
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

  IconData _getAlertIcon(String alertType) {
    switch (alertType) {
      case 'ROBBERY':
        return Icons.person_off;
      case 'FIRE':
        return Icons.local_fire_department;
      case 'ACCIDENT':
        return Icons.car_crash;
      case 'STREET ESCORT':
        return Icons.people;
      case 'UNSAFETY':
        return Icons.warning;
      case 'PHYSICAL RISK':
        return Icons.accessibility;
      case 'PUBLIC SERVICES EMERGENCY':
        return Icons.construction;
      case 'VIAL EMERGENCY':
        return Icons.directions_car;
      case 'ASSISTANCE':
        return Icons.help;
      case 'EMERGENCY':
        return Icons.emergency;
      default:
        return Icons.warning;
    }
  }

  Color _getAlertColor(String alertType) {
    switch (alertType) {
      case 'ROBBERY':
      case 'FIRE':
      case 'EMERGENCY':
        return Colors.red;
      case 'ACCIDENT':
      case 'VIAL EMERGENCY':
        return Colors.orange;
      case 'UNSAFETY':
      case 'PHYSICAL RISK':
        return Colors.purple;
      case 'STREET ESCORT':
      case 'ASSISTANCE':
        return Colors.blue;
      case 'PUBLIC SERVICES EMERGENCY':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Solicita optimización de batería para el servicio en segundo plano
  Future<void> _requestBatteryOptimization() async {
    try {
      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Verificando optimización de batería...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Verificar si ya está optimizado
      final isIgnored = await NativeBackgroundService.isBatteryOptimizationIgnored();
      
      if (isIgnored) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('✅ La optimización de batería ya está configurada'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Solicitar exención
      await NativeBackgroundService.requestBatteryOptimizationExemption();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.white),
                    SizedBox(width: 12),
                    Text('🔋 Configuración de Batería'),
                  ],
                ),
                SizedBox(height: 4),
                Text('Para un funcionamiento óptimo, permite que Guardian ignore la optimización de batería.'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text('❌ Error: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildAlertButtonSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Título de la sección
          const Text(
            'Emergency Button',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Swipe in any direction for specific emergency type',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 30),
          
          // Botón de alerta con tamaño fijo para mantener proporción
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: AlertButton(
                    onPressed: () {
                      // TODO: Implement general alert
                    },
                  ),
                ),
              ),
            ),
          ),
          
          // Información adicional
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFF4CAF50),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Hold and swipe to activate different emergency types',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF4CAF50),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Botón para configurar optimización de batería
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      _requestBatteryOptimization();
                    },
                    icon: const Icon(Icons.battery_saver, size: 18),
                    label: const Text('Optimizar Servicio', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}