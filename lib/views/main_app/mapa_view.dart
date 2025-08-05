import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../models/alert_model.dart';
import '../../controllers/map_controller.dart' as map_data;

class MapaView extends StatefulWidget {
  final AlertModel? selectedAlert;

  const MapaView({super.key, this.selectedAlert});

  @override
  State<MapaView> createState() => _MapaViewState();
}

class _MapaViewState extends State<MapaView> {
  final flutter_map.MapController _mapController = flutter_map.MapController();
  final map_data.MapController _mapDataController = map_data.MapController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<AlertModel> _alerts = [];
  AlertModel? _selectedAlertForDetails;
  bool _isLoading = true;
  LatLng? _currentLocation;
  StreamSubscription<List<AlertModel>>? _alertsSubscription;

  // Define alert types exactly as they appear in AlertButton
  final Map<String, Map<String, dynamic>> _alertTypes = {
    'STREET ESCORT': {
      'icon': Icons.people,
      'color': Colors.blue,
      'category': 'Assistance',
    },
    'ROBBERY': {
      'icon': Icons.person_off,
      'color': Colors.red,
      'category': 'Critical Emergency',
    },
    'UNSAFETY': {
      'icon': Icons.warning,
      'color': Colors.orange,
      'category': 'Risk',
    },
    'PHYSICAL RISK': {
      'icon': Icons.accessibility,
      'color': Colors.purple,
      'category': 'Risk',
    },
    'PUBLIC SERVICES EMERGENCY': {
      'icon': Icons.construction,
      'color': Colors.yellow,
      'category': 'Public Services',
    },
    'VIAL EMERGENCY': {
      'icon': Icons.directions_car,
      'color': Colors.cyan,
      'category': 'Traffic',
    },
    'ASSISTANCE': {
      'icon': Icons.help,
      'color': Colors.green,
      'category': 'Assistance',
    },
    'FIRE': {
      'icon': Icons.local_fire_department,
      'color': Colors.red,
      'category': 'Critical Emergency',
    },
    'ACCIDENT': {
      'icon': Icons.car_crash,
      'color': Colors.orange,
      'category': 'Accident',
    },
    'EMERGENCY': {
      'icon': Icons.emergency,
      'color': Colors.red,
      'category': 'Critical Emergency',
    },
  };

  @override
  void initState() {
    super.initState();
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

  List<flutter_map.Marker> _createMarkers() {
    return _alerts.map((alert) {
      if (alert.location == null) return null;
      
      final latLng = LatLng(alert.location!.latitude, alert.location!.longitude);
      
      return flutter_map.Marker(
        point: latLng,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showAlertDetails(alert),
          child: Container(
            decoration: BoxDecoration(
              color: _getAlertColor(alert.alertType),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
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
        ),
      );
    }).where((marker) => marker != null).cast<flutter_map.Marker>().toList();
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(8),
      width: 180, // Make it more compact
      constraints: const BoxConstraints(maxHeight: 300), // Limit height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView( // Make it scrollable if needed
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alert Types',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...categories.entries.map((category) => _buildCategorySection(category.key, category.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String category, List<String> alertTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        ...alertTypes.map((alertType) => _buildLegendItem(
          _getAlertColor(alertType),
          alertType,
          _getAlertIcon(alertType),
        )),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 8,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 9),
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
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
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
                          child: Text(
                            alert.isAnonymous 
                                ? 'Anonymous Report'
                                : 'Reported by ${alert.userName ?? 'Unknown User'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
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
        title: const Text('Alerts Map'),
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
          
          // Panel de detalles de alerta
          _buildAlertDetailsPanel(),
          
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
                child: const Text(
                  'No alerts found',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _alertsSubscription?.cancel();
    super.dispose();
  }
}
