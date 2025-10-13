import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para haptic feedback
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import '../../models/alert_model.dart';
import '../../models/emergency_types.dart';
import '../../controllers/map_controller.dart' as map_data;
import '../../generated/l10n/app_localizations.dart';

class MapaView extends StatefulWidget {
  final AlertModel? selectedAlert;

  const MapaView({super.key, this.selectedAlert});

  @override
  State<MapaView> createState() => _MapaViewState();
}

class _MapaViewState extends State<MapaView> with TickerProviderStateMixin {
  final flutter_map.MapController _mapController = flutter_map.MapController();
  final map_data.MapController _mapDataController = map_data.MapController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<AlertModel> _alerts = [];
  AlertModel? _selectedAlertForDetails;
  bool _isLoading = true;
  LatLng? _currentLocation;
  StreamSubscription<List<AlertModel>>? _alertsSubscription;
  
  // Variables para el panel plegable
  bool _isLegendExpanded = true;
  late AnimationController _legendAnimationController;
  late Animation<double> _legendAnimation;

  // Usar el sistema centralizado de tipos de emergencia
  Map<String, Map<String, dynamic>> get _alertTypes {
    final Map<String, Map<String, dynamic>> alertTypes = {};
    
    // Obtener todos los tipos del sistema centralizado
    for (final direction in EmergencyTypes.allDirections) {
      final typeData = EmergencyTypes.getTypeByDirection(direction);
      if (typeData != null) {
        final typeName = typeData['type'] as String;
        alertTypes[typeName] = {
          'icon': typeData['icon'],
          'color': typeData['color'],
          'category': _getCategoryForType(typeName),
        };
      }
    }
    
    return alertTypes;
  }
  
  // Función auxiliar para categorizar los tipos
  String _getCategoryForType(String typeName) {
    switch (typeName) {
      case 'ROBBERY':
      case 'FIRE':
        return 'Critical Emergency';
      case 'UNSAFETY':
      case 'PHYSICAL RISK':
        return 'Risk';
      case 'STREET ESCORT':
      case 'ASSISTANCE':
        return 'Assistance';
      case 'PUBLIC SERVICES EMERGENCY':
        return 'Public Services';
      case 'VIAL EMERGENCY':
        return 'Traffic';
      default:
        return 'Other';
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Inicializar controlador de animación tipo Apple
    _legendAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _legendAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _legendAnimationController,
      curve: Curves.easeInOutCubic, // Curva más suave tipo Apple
    ));
    
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    _startListeningToAlerts();
    
    // Si hay una alerta seleccionada, centrar el mapa en ella
    if (widget.selectedAlert != null) {
      _centerMapOnAlert(widget.selectedAlert!);
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  void _startListeningToAlerts() {
    _alertsSubscription = _mapDataController.getAlertsStream().listen(
      (alerts) {
        setState(() {
          _alerts = alerts;
        });
        print('Received ${alerts.length} alerts from stream');
      },
      onError: (error) {
        print('Error listening to alerts: $error');
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _refreshAlerts() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final alerts = await _mapDataController.getAlertsOnce();
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
      print('Refreshed alerts: ${alerts.length} found');
    } catch (e) {
      print('Error refreshing alerts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Función para calcular la distancia entre dos puntos
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Radio de la Tierra en metros
    final double lat1Rad = point1.latitude * pi / 180;
    final double lat2Rad = point2.latitude * pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * pi / 180;
    final double deltaLonRad = (point2.longitude - point1.longitude) * pi / 180;

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLonRad / 2) * sin(deltaLonRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Función para aplicar offset a marcadores superpuestos
  List<Map<String, dynamic>> _applyMarkerOffsets(List<AlertModel> alerts) {
    if (alerts.isEmpty) return [];

    final List<Map<String, dynamic>> markersWithOffsets = [];
    const double overlapThreshold = 50.0; // Distancia en metros para considerar superposición
    const double offsetDistance = 0.0001; // Aproximadamente 10 metros en grados

    for (int i = 0; i < alerts.length; i++) {
      final alert = alerts[i];
      if (alert.location == null) continue;

      final originalLatLng = LatLng(alert.location!.latitude, alert.location!.longitude);
      LatLng adjustedLatLng = originalLatLng;
      int offsetLevel = 0;

      // Verificar si hay superposición con marcadores ya procesados
      for (int j = 0; j < markersWithOffsets.length; j++) {
        final existingMarker = markersWithOffsets[j];
        final existingLatLng = existingMarker['latLng'] as LatLng;
        
        final distance = _calculateDistance(originalLatLng, existingLatLng);
        
        if (distance < overlapThreshold) {
          // Aplicar offset en espiral
          offsetLevel++;
          final angle = (offsetLevel * 2 * pi) / 8; // 8 posiciones en círculo
          final radius = offsetDistance * offsetLevel;
          
          adjustedLatLng = LatLng(
            originalLatLng.latitude + radius * cos(angle),
            originalLatLng.longitude + radius * sin(angle),
          );
        }
      }

      markersWithOffsets.add({
        'alert': alert,
        'latLng': adjustedLatLng,
        'originalLatLng': originalLatLng,
        'hasOffset': offsetLevel > 0,
        'offsetLevel': offsetLevel,
      });
    }

    return markersWithOffsets;
  }

  List<flutter_map.Marker> _createMarkers() {
    final markersWithOffsets = _applyMarkerOffsets(_alerts);
    
    return markersWithOffsets.map((markerData) {
      final alert = markerData['alert'] as AlertModel;
      final latLng = markerData['latLng'] as LatLng;
      final hasOffset = markerData['hasOffset'] as bool;
      final offsetLevel = markerData['offsetLevel'] as int;
      
      return flutter_map.Marker(
        point: latLng,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showAlertDetails(alert),
          child: Stack(
            children: [
              // Marcador principal
              Container(
                decoration: BoxDecoration(
                  color: _getAlertColor(alert.alertType),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasOffset ? Colors.yellow : Colors.white, 
                    width: hasOffset ? 3 : 2
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _getAlertIcon(alert.alertType),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              
              // Indicador de offset (pequeño punto amarillo)
              if (hasOffset)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.yellow,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${offsetLevel + 1}',
                        style: const TextStyle(
                          fontSize: 6,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showAlertDetails(AlertModel alert) {
    setState(() {
      _selectedAlertForDetails = alert;
    });
  }

  void _hideAlertDetails() {
    setState(() {
      _selectedAlertForDetails = null;
    });
  }

  void _toggleLegend() {
    // Haptic feedback tipo Apple
    HapticFeedback.lightImpact();
    
    setState(() {
      _isLegendExpanded = !_isLegendExpanded;
    });
    
    if (_isLegendExpanded) {
      _legendAnimationController.forward();
    } else {
      _legendAnimationController.reverse();
    }
  }

  void _centerMapOnAlert(AlertModel alert) {
    if (alert.location == null) return;
    
    final latLng = LatLng(alert.location!.latitude, alert.location!.longitude);
    _mapController.move(latLng, 15.0);
  }

  IconData _getAlertIcon(String alertType) {
    return _alertTypes[alertType]?['icon'] ?? Icons.warning;
  }

  Color _getAlertColor(String alertType) {
    return _alertTypes[alertType]?['color'] ?? Colors.grey;
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Widget _buildLegend() {
    // Group alert types by category
    final categories = <String, List<String>>{};
    for (final entry in _alertTypes.entries) {
      final category = entry.value['category'] as String;
      categories.putIfAbsent(category, () => []).add(entry.key);
    }

    return Container(
      margin: const EdgeInsets.all(20),
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          // Sombra principal tipo Apple
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          // Sombra sutil adicional
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header premium tipo Apple
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleLegend,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1D1D1F), // Negro Apple
                      const Color(0xFF2C2C2E), // Gris oscuro Apple
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    // Icono de información
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.alerts,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    // Botón de toggle con animación suave
                    AnimatedRotation(
                      turns: _isLegendExpanded ? 0.0 : 0.5,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Contenido plegable con animación premium
          AnimatedBuilder(
            animation: _legendAnimation,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _isLegendExpanded ? 1.0 : 0.0,
                  child: child,
                ),
              );
            },
            child: Container(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      ...categories.entries.map((category) => _buildCategorySection(category.key, category.value)),
                      
                      // Información sobre marcadores con offset - diseño premium
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.amber.withValues(alpha: 0.1),
                              Colors.orange.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.amber, Colors.orange],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  '1',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.alerts,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1D1D1F),
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String category, List<String> alertTypes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de categoría con estilo Apple
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7), // Gris claro Apple
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              category.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93), // Gris Apple
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Items de la categoría
          ...alertTypes.map((alertType) => _buildLegendItem(
            _getAlertColor(alertType),
            alertType,
            _getAlertIcon(alertType),
          )),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // Marcador con sombra y gradiente
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  color.withValues(alpha: 0.8),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 10,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              EmergencyTypes.getTranslatedType(label, context),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1D1D1F),
                letterSpacing: -0.1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertDetailsPanel() {
    if (_selectedAlertForDetails == null) return const SizedBox.shrink();
    
    final alert = _selectedAlertForDetails!;
    
    return Container(
      margin: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxHeight: 300), // Limit height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView( // Make it scrollable if needed
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getAlertColor(alert.alertType),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getAlertIcon(alert.alertType),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.alertType,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _getTimeAgo(alert.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _hideAlertDetails,
                  ),
                ],
              ),
            ),
            
            // Contenido de la alerta
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del usuario
                  Row(
                    children: [
                      Icon(
                        alert.isAnonymous ? Icons.visibility_off : Icons.person,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                                             Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               alert.isAnonymous 
                                   ? 'Anonymous Report'
                                   : 'Reported by:',
                               style: TextStyle(
                                 fontSize: 12,
                                 color: Colors.grey[600],
                                 fontWeight: FontWeight.w500,
                               ),
                             ),
                             if (!alert.isAnonymous)
                               Text(
                                 alert.userName ?? 'Unknown User',
                                 style: TextStyle(
                                   fontSize: 14,
                                   color: Colors.grey[800],
                                   fontWeight: FontWeight.w600,
                                 ),
                                 overflow: TextOverflow.ellipsis,
                                 maxLines: 2,
                               ),
                           ],
                         ),
                       ),
                    ],
                  ),
                  
                  // Descripción
                  if (alert.description != null && alert.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      alert.description!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                  
                  // Información adicional
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (alert.shareLocation && alert.location != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '📍 Location',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getAlertColor(alert.alertType).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          alert.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getAlertColor(alert.alertType),
                            fontWeight: FontWeight.w500,
                          ),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Usar ubicación por defecto si no se puede obtener la actual
    final initialLocation = _currentLocation ?? const LatLng(4.7110, -74.0721); // Bogotá, Colombia

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.map),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAlerts,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa como fondo
          flutter_map.FlutterMap(
            mapController: _mapController,
            options: flutter_map.MapOptions(
              initialCenter: initialLocation,
              initialZoom: 13.0,
              interactionOptions: const flutter_map.InteractionOptions(
                flags: flutter_map.InteractiveFlag.all,
              ),
              onMapReady: () {
                // Si hay una alerta seleccionada, centrar el mapa en ella
                if (widget.selectedAlert != null) {
                  _centerMapOnAlert(widget.selectedAlert!);
                }
              },
            ),
            children: [
              flutter_map.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.guardian',
              ),
              flutter_map.MarkerLayer(
                markers: _createMarkers(),
              ),
            ],
          ),
          
          // Leyenda
          Positioned(
            top: 16,
            right: 16,
            child: _buildLegend(),
          ),
          
          // Debug info
          if (_alerts.isEmpty)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context)!.noRecentAlerts,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          
          // Panel de detalles de alerta (en la parte superior para no bloquear el mapa)
          if (_selectedAlertForDetails != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildAlertDetailsPanel(),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _alertsSubscription?.cancel();
    _legendAnimationController.dispose();
    super.dispose();
  }
}
