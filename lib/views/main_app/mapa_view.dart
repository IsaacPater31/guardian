import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import '../../core/app_logger.dart';
import '../../models/alert_model.dart';
import '../../models/emergency_types.dart';
import '../../handlers/map_handler.dart' as map_data;
import '../../generated/l10n/app_localizations.dart';
import 'widgets/map_filter_sheet.dart';

class MapaView extends StatefulWidget {
  final AlertModel? selectedAlert;

  const MapaView({super.key, this.selectedAlert});

  @override
  State<MapaView> createState() => _MapaViewState();
}

class _MapaViewState extends State<MapaView> with TickerProviderStateMixin {
  final flutter_map.MapController _mapController = flutter_map.MapController();
  final map_data.MapHandler _mapDataController = map_data.MapHandler();

  List<AlertModel> _alerts = [];
  AlertModel? _selectedAlertForDetails;
  bool _isLoading = true;
  LatLng? _currentLocation;
  StreamSubscription<List<AlertModel>>? _alertsSubscription;

  // ─── Filtros ───────────────────────────────────────────────────────────────
  MapFilters _filters = MapFilters.empty;

  // Usar el sistema centralizado de tipos de emergencia
  Map<String, Map<String, dynamic>> get _alertTypes {
    final Map<String, Map<String, dynamic>> alertTypes = {};
    for (final direction in EmergencyTypes.allDirections) {
      final typeData = EmergencyTypes.getTypeByDirection(direction);
      if (typeData != null) {
        final typeName = typeData['type'] as String;
        alertTypes[typeName] = {
          'icon': typeData['icon'],
          'color': typeData['color'],
        };
      }
    }
    return alertTypes;
  }

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    _subscribeToAlerts();

    if (widget.selectedAlert != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerMapOnAlert(widget.selectedAlert!);
      });
    }

    setState(() => _isLoading = false);
  }

  // ─── Suscripción reactiva a alertas ────────────────────────────────────────

  void _subscribeToAlerts() {
    _alertsSubscription?.cancel();

    final stream = _mapDataController.getAlertsStreamFiltered(
      selectedTypes: _filters.types.toList(),
      filterStatus: _filters.status,
      filterDateRange: _filters.dateRange,
      customStart: _filters.customStart,
      customEnd: _filters.customEnd,
    );

    _alertsSubscription = stream.listen(
      (alerts) {
        if (mounted) setState(() => _alerts = alerts);
        AppLogger.d('Map stream: ${alerts.length} alerts received');
      },
      onError: (error) => AppLogger.e('Map stream error', error),
    );
  }

  // ─── Aplicar nuevos filtros ────────────────────────────────────────────────

  void _applyFilters(MapFilters newFilters) {
    setState(() {
      _filters = newFilters;
      _isLoading = true;
    });
    _subscribeToAlerts();
    // Pequeño delay para que el spinner sea visible y luego el stream responda
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  // ─── Panel de filtros ──────────────────────────────────────────────────────

  void _showFilterSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => MapFilterSheet(
          initial: _filters,
          onApply: _applyFilters,
        ),
      ),
    );
  }

  // ─── Ubicación ─────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      AppLogger.e('MapaView._getCurrentLocation', e);
    }
  }

  Future<void> _refreshAlerts() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    _subscribeToAlerts();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoading = false);
  }

  // ─── Marcadores ────────────────────────────────────────────────────────────

  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000;
    final double lat1Rad = p1.latitude * pi / 180;
    final double lat2Rad = p2.latitude * pi / 180;
    final double deltaLatRad = (p2.latitude - p1.latitude) * pi / 180;
    final double deltaLonRad = (p2.longitude - p1.longitude) * pi / 180;
    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLonRad / 2) * sin(deltaLonRad / 2);
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  List<Map<String, dynamic>> _applyMarkerOffsets(List<AlertModel> alerts) {
    if (alerts.isEmpty) return [];
    final List<Map<String, dynamic>> result = [];
    const double overlapThreshold = 50.0;
    const double offsetDistance = 0.0001;

    for (int i = 0; i < alerts.length; i++) {
      final alert = alerts[i];
      if (alert.location == null) continue;

      final originalLatLng = LatLng(alert.location!.latitude, alert.location!.longitude);
      LatLng adjustedLatLng = originalLatLng;
      int offsetLevel = 0;

      for (final existing in result) {
        final existingLatLng = existing['latLng'] as LatLng;
        if (_calculateDistance(originalLatLng, existingLatLng) < overlapThreshold) {
          offsetLevel++;
          final angle = (offsetLevel * 2 * pi) / 8;
          final radius = offsetDistance * offsetLevel;
          adjustedLatLng = LatLng(
            originalLatLng.latitude + radius * cos(angle),
            originalLatLng.longitude + radius * sin(angle),
          );
        }
      }

      result.add({
        'alert': alert,
        'latLng': adjustedLatLng,
        'hasOffset': offsetLevel > 0,
        'offsetLevel': offsetLevel,
      });
    }
    return result;
  }

  List<flutter_map.Marker> _createMarkers() {
    return _applyMarkerOffsets(_alerts).map((data) {
      final alert = data['alert'] as AlertModel;
      final latLng = data['latLng'] as LatLng;
      final hasOffset = data['hasOffset'] as bool;
      final offsetLevel = data['offsetLevel'] as int;
      final isAttended = alert.alertStatus == 'attended';

      return flutter_map.Marker(
        point: latLng,
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showAlertDetails(alert),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _getAlertColor(alert.alertType),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasOffset ? Colors.yellow : Colors.white,
                    width: hasOffset ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
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
              // Badge "atendida" — checkmark verde
              if (isAttended)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Color(0xFF34C759),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 9),
                  ),
                ),
              // Badge de offset
              if (hasOffset && !isAttended)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 10,
                    height: 10,
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

  // ─── Panel de detalle de alerta ────────────────────────────────────────────

  void _showAlertDetails(AlertModel alert) {
    setState(() => _selectedAlertForDetails = alert);
  }

  void _hideAlertDetails() {
    setState(() => _selectedAlertForDetails = null);
  }

  void _centerMapOnAlert(AlertModel alert) {
    if (alert.location == null) return;
    _mapController.move(
      LatLng(alert.location!.latitude, alert.location!.longitude),
      15.0,
    );
  }

  // ─── Helpers de tipo ───────────────────────────────────────────────────────

  IconData _getAlertIcon(String alertType) =>
      _alertTypes[alertType]?['icon'] ?? Icons.warning;

  Color _getAlertColor(String alertType) =>
      _alertTypes[alertType]?['color'] ?? Colors.grey;

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return AppLocalizations.of(context)!.justNowMap;
    if (diff.inMinutes < 60) return AppLocalizations.of(context)!.minutesAgoMap(diff.inMinutes);
    if (diff.inHours < 24) return AppLocalizations.of(context)!.hoursAgoMap(diff.inHours);
    return AppLocalizations.of(context)!.daysAgoMap(diff.inDays);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _alerts.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final initialLocation = _currentLocation ?? const LatLng(4.7110, -74.0721);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.map),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshAlerts,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Mapa ──
          flutter_map.FlutterMap(
            mapController: _mapController,
            options: flutter_map.MapOptions(
              initialCenter: initialLocation,
              initialZoom: 13.0,
              interactionOptions: const flutter_map.InteractionOptions(
                flags: flutter_map.InteractiveFlag.all,
              ),
              onMapReady: () {
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
              flutter_map.MarkerLayer(markers: _createMarkers()),
            ],
          ),

          // ── Botón de filtro (esquina superior derecha) ──
          Positioned(
            top: 16,
            right: 16,
            child: _buildFilterButton(),
          ),

          // ── Chip: sin alertas ──
          if (_alerts.isEmpty && !_isLoading)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _filters.hasFilters
                          ? 'Sin alertas para los filtros aplicados'
                          : AppLocalizations.of(context)!.noRecentAlerts,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // ── Chip: conteo de resultados (cuando hay filtros activos) ──
          if (_filters.hasFilters && _alerts.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              child: _buildResultCountChip(),
            ),

          // ── Loading overlay (actualizando) ──
          if (_isLoading && _alerts.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Actualizando...', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // ── Panel de detalle de alerta ──
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

  // ─── Botón de filtro flotante ──────────────────────────────────────────────

  Widget _buildFilterButton() {
    final hasActive = _filters.hasFilters;

    return GestureDetector(
      onTap: _showFilterSheet,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: hasActive ? const Color(0xFF0D1B3E) : Colors.white,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 18,
              color: hasActive ? Colors.white : const Color(0xFF374151),
            ),
            const SizedBox(width: 7),
            Text(
              'Filtros',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasActive ? Colors.white : const Color(0xFF374151),
              ),
            ),
            if (hasActive) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${_filters.activeCount}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Chip de conteo de resultados ──────────────────────────────────────────

  Widget _buildResultCountChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF34C759),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '${_alerts.length} alerta${_alerts.length != 1 ? "s" : ""} visibles',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Panel de detalle ──────────────────────────────────────────────────────

  Widget _buildAlertDetailsPanel() {
    if (_selectedAlertForDetails == null) return const SizedBox.shrink();
    final alert = _selectedAlertForDetails!;
    final isAttended = alert.alertStatus == 'attended';

    return Container(
      margin: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getAlertColor(alert.alertType),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_getAlertIcon(alert.alertType), color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          EmergencyTypes.getTranslatedType(alert.alertType, context),
                          style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _getTimeAgo(alert.timestamp),
                              style: TextStyle(
                                fontSize: 12, color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Badge de estado — Apple-style pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:        isAttended
                                    ? const Color(0xFF34C759).withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isAttended
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : Colors.white.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAttended
                                        ? Icons.check_circle_rounded
                                        : Icons.schedule_rounded,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isAttended ? 'Atendida' : 'No atendida',
                                    style: const TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: _hideAlertDetails,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        alert.isAnonymous ? Icons.visibility_off_rounded : Icons.person_rounded,
                        size: 15,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alert.isAnonymous
                              ? AppLocalizations.of(context)!.anonymousReportMap
                              : (alert.userName ?? AppLocalizations.of(context)!.unknownUser),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (alert.description != null && alert.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      alert.description!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (alert.shareLocation && alert.location != null)
                        _buildTag('📍 Ubicación', Colors.green),
                      _buildTag(alert.type.toUpperCase(), _getAlertColor(alert.alertType)),
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

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
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

