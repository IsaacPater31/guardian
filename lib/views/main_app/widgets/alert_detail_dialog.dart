import 'package:flutter/material.dart';
import 'package:guardian/models/alert_model.dart';
import 'package:guardian/models/community_model.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:guardian/controllers/alert_controller.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/services/community_repository.dart';
import 'package:guardian/views/main_app/community_feed_view.dart';
import 'dart:convert';

class AlertDetailDialog extends StatefulWidget {
  final AlertModel alert;

  const AlertDetailDialog({super.key, required this.alert});

  @override
  State<AlertDetailDialog> createState() => _AlertDetailDialogState();
}

class _AlertDetailDialogState extends State<AlertDetailDialog> {
  final AlertController _alertController = AlertController();
  final CommunityService _communityService = CommunityService();
  final CommunityRepository _communityRepository = CommunityRepository();
  String? _communityName;
  bool _isLoadingCommunity = false;

  /// Obtiene el tipo de alerta traducido
  String _getTranslatedAlertType() {
    return EmergencyTypes.getTranslatedType(widget.alert.alertType, context);
  }

  @override
  void initState() {
    super.initState();
    // Marcar la alerta como vista cuando se abre el diálogo
    if (widget.alert.id != null) {
      _alertController.markAlertAsViewed(widget.alert.id!);
    }
    // Cargar nombre de la comunidad si la alerta tiene community_id
    if (widget.alert.communityId != null && widget.alert.communityId!.isNotEmpty) {
      _loadCommunityName();
    }
  }
  
  Future<void> _loadCommunityName() async {
    if (widget.alert.communityId == null) return;
    
    setState(() => _isLoadingCommunity = true);
    try {
      final community = await _communityRepository.getCommunityById(widget.alert.communityId!);
      if (community != null && mounted) {
        setState(() {
          _communityName = community.name;
          _isLoadingCommunity = false;
        });
      } else {
        setState(() => _isLoadingCommunity = false);
      }
    } catch (e) {
      print('Error cargando nombre de comunidad: $e');
      if (mounted) {
        setState(() => _isLoadingCommunity = false);
      }
    }
  }
  
  Future<void> _navigateToCommunity() async {
    if (widget.alert.communityId == null) return;
    
    // Verificar que el usuario es miembro de la comunidad
    final role = await _communityService.getUserRole(widget.alert.communityId!);
    if (role == null) {
      // Usuario no es miembro
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No eres miembro de esta comunidad'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Obtener información de la comunidad
    final community = await _communityRepository.getCommunityById(widget.alert.communityId!);
    if (community == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comunidad no encontrada'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Navegar al feed de la comunidad
    if (mounted) {
      Navigator.of(context).pop(); // Cerrar diálogo
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CommunityFeedView(
            communityId: widget.alert.communityId!,
            communityName: community.name,
            isEntity: community.isEntity,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 25,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con información de la alerta
            _buildHeader(context),
            
            // Contenido scrolleable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                                // Tipo de alerta
            _buildAlertTypeSection(),
            
            const SizedBox(height: 24),
            
            // Descripción
            if (widget.alert.description != null && widget.alert.description!.isNotEmpty) ...[
              _buildDescriptionSection(),
              const SizedBox(height: 16),
            ],
            
            // Contadores de reenvíos y reportes
            if (widget.alert.forwardsCount > 0 || widget.alert.reportsCount > 0) ...[
              _buildCountersSection(),
              const SizedBox(height: 16),
            ],
            
            // Ubicación
            if (widget.alert.shareLocation && widget.alert.location != null) ...[
              const SizedBox(height: 24),
              _buildLocationSection(),
              _buildLocationMapSection(),
            ],
            
            // Información adicional
            const SizedBox(height: 24),
            _buildAdditionalInfoSection(),
            
            // Imágenes (si las hay)
            if (widget.alert.imageBase64 != null && widget.alert.imageBase64!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildImagesSection(),
            ],
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            
            // Botones de acción
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final alertColor = _getAlertColor(widget.alert.alertType);
    final alertIcon = _getAlertIcon(widget.alert.alertType);
    
    return Container(
      decoration: BoxDecoration(
        color: alertColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: alertColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Icono de alerta
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              alertIcon,
              color: Colors.white,
              size: 35,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Título de la alerta
          Text(
            _getTranslatedAlertType(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Fecha y hora
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatDateTime(widget.alert.timestamp),
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertTypeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getAlertColor(widget.alert.alertType).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getAlertColor(widget.alert.alertType).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _getAlertIcon(widget.alert.alertType),
            color: _getAlertColor(widget.alert.alertType),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.alertType,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getTranslatedAlertType(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getAlertColor(widget.alert.alertType),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: Color(0xFF1F2937),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.alert.description!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1F2937),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          // Contador de reenvíos
          if (widget.alert.forwardsCount > 0) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.forward, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.alert.forwardsCount}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.alert.forwardsCount == 1 ? 'reenvío' : 'reenvíos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Contador de reportes
          if (widget.alert.reportsCount > 0) ...[
            if (widget.alert.forwardsCount > 0) const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.report, color: Colors.orange[700], size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.alert.reportsCount}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.alert.reportsCount == 1 ? 'reporte' : 'reportes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.location,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.alert.location!.latitude.toStringAsFixed(6)}, ${widget.alert.location!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMapSection() {
    if (widget.alert.location == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(widget.alert.location!.latitude, widget.alert.location!.longitude),
                initialZoom: 16.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.guardian',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(widget.alert.location!.latitude, widget.alert.location!.longitude),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getAlertColor(widget.alert.alertType),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getAlertIcon(widget.alert.alertType),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Overlay con información
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context)!.alertLocation,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.additionalInfo,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          
          // Estado anónimo
          Row(
            children: [
              Icon(
                widget.alert.isAnonymous ? Icons.visibility_off : Icons.visibility,
                color: widget.alert.isAnonymous ? Colors.orange : Colors.green,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                widget.alert.isAnonymous ? AppLocalizations.of(context)!.anonymousReport : AppLocalizations.of(context)!.identifiedReport,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.alert.isAnonymous ? Colors.orange : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Compartir ubicación
          Row(
            children: [
              Icon(
                widget.alert.shareLocation ? Icons.location_on : Icons.location_off,
                color: widget.alert.shareLocation ? Colors.green : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                widget.alert.shareLocation ? AppLocalizations.of(context)!.locationShared : AppLocalizations.of(context)!.locationNotShared,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.alert.shareLocation ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Contador de vistas
          if (widget.alert.viewedCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.visibility,
                  color: Colors.blue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '${AppLocalizations.of(context)!.viewedBy} ${widget.alert.viewedCount} ${widget.alert.viewedCount > 1 ? AppLocalizations.of(context)!.people : AppLocalizations.of(context)!.person}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          
          // Información del usuario (si no es anónimo)
          if (!widget.alert.isAnonymous && widget.alert.userName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.person,
                  color: Color(0xFF6B7280),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.reportedBy,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        widget.alert.userName!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
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
          ],
        ],
      ),
    );
  }

  Widget _buildImagesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: Color(0xFF1F2937),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.images,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Mostrar imágenes
          if (widget.alert.imageBase64 != null && widget.alert.imageBase64!.isNotEmpty)
            ...widget.alert.imageBase64!.map((base64String) => _buildImageItem(base64String)),
        ],
      ),
    );
  }

  Widget _buildImageItem(String base64String) {
    try {
      final bytes = base64Decode(base64String);
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 200,
          ),
        ),
      );
    } catch (e) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.errorLoadingImage,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
  }

  /// Muestra diálogo para reenviar alerta a otras comunidades
  Future<void> _showForwardDialog() async {
    if (widget.alert.id == null) return;

    // Cargar comunidades del usuario
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final allCommunities = await _communityService.getMyCommunities();
      
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
      }

      // Obtener información de la comunidad original (si existe)
      CommunityModel? originalCommunity;
      bool canForwardToEntities = true;
      
      if (widget.alert.communityId != null && widget.alert.communityId!.isNotEmpty) {
        originalCommunity = await _communityRepository.getCommunityById(widget.alert.communityId!);
        canForwardToEntities = originalCommunity?.allowForwardToEntities ?? true;
      }

      // Filtrar comunidades disponibles:
      // 1. Excluir la comunidad de origen
      // 2. Si no se permite reenvío a entidades, excluir entidades
      final availableCommunities = allCommunities.where((c) {
        final id = c['id'] as String;
        final isEntity = c['is_entity'] as bool;
        
        // Excluir comunidad de origen
        if (widget.alert.communityId == id) {
          return false;
        }
        
        // Si no se permite reenvío a entidades, excluir entidades
        if (isEntity && !canForwardToEntities) {
          return false;
        }
        
        return true;
      }).toList();

      if (availableCommunities.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay comunidades disponibles para reenviar'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // Mostrar diálogo de selección
      final selectedIds = await showDialog<Set<String>>(
        context: context,
        builder: (context) => _ForwardAlertDialog(
          availableCommunities: availableCommunities,
          canForwardToEntities: canForwardToEntities,
        ),
      );

      if (selectedIds == null || selectedIds.isEmpty) return;

      // Reenviar alerta
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final successCount = await _alertController.forwardAlert(
          alertId: widget.alert.id!,
          targetCommunityIds: selectedIds.toList(),
        );

        if (mounted) {
          Navigator.pop(context); // Cerrar loading
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Alerta reenviada a $successCount ${successCount == 1 ? 'comunidad' : 'comunidades'}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Cerrar loading
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error reenviando alerta: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading si aún está abierto
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    final hasCommunity = widget.alert.communityId != null && widget.alert.communityId!.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón para ir a la comunidad (solo si tiene community_id)
          if (hasCommunity) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoadingCommunity ? null : _navigateToCommunity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F2937),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                icon: _isLoadingCommunity
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.people, size: 20),
                label: Text(
                  _isLoadingCommunity
                      ? 'Cargando...'
                      : _communityName != null
                          ? 'Ver en $_communityName'
                          : 'Ver en Comunidad',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Botón de reenviar
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.alert.id != null ? _showForwardDialog : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(
                  color: Colors.blue.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              icon: const Icon(Icons.forward, size: 20),
              label: const Text(
                'Reenviar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Botones principales
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                      color: const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.close,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implementar acción de respuesta
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getAlertColor(widget.alert.alertType),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    shadowColor: _getAlertColor(widget.alert.alertType).withValues(alpha: 0.3),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.respond,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

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
}

/// Diálogo para seleccionar comunidades destino al reenviar alerta
class _ForwardAlertDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableCommunities;
  final bool canForwardToEntities;

  const _ForwardAlertDialog({
    required this.availableCommunities,
    required this.canForwardToEntities,
  });

  @override
  State<_ForwardAlertDialog> createState() => _ForwardAlertDialogState();
}

class _ForwardAlertDialogState extends State<_ForwardAlertDialog> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    // Separar entidades y comunidades normales
    final entities = widget.availableCommunities.where((c) => c['is_entity'] == true).toList();
    final normalCommunities = widget.availableCommunities.where((c) => c['is_entity'] != true).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.forward, color: Color(0xFF1F2937)),
          const SizedBox(width: 8),
          const Text('Reenviar Alerta'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona a qué comunidades reenviar esta alerta:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              
              // Sección de entidades (si hay y está permitido)
              if (entities.isNotEmpty && widget.canForwardToEntities) ...[
                const Text(
                  'Entidades Oficiales',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                ...entities.map((entity) => _buildCommunityCheckbox(entity)),
                const SizedBox(height: 16),
              ],
              
              // Sección de comunidades normales
              if (normalCommunities.isNotEmpty) ...[
                const Text(
                  'Comunidades',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                ...normalCommunities.map((community) => _buildCommunityCheckbox(community)),
              ],
              
              if (entities.isEmpty && normalCommunities.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No hay comunidades disponibles para reenviar',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedIds),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F2937),
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Reenviar (${_selectedIds.length})',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityCheckbox(Map<String, dynamic> community) {
    final id = community['id'] as String;
    final name = community['name'] as String;
    final isEntity = community['is_entity'] as bool;
    final isSelected = _selectedIds.contains(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedIds.add(id);
            } else {
              _selectedIds.remove(id);
            }
          });
        },
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: isEntity
            ? Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Entidad Oficial',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isEntity
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isEntity ? Icons.shield : Icons.people,
            color: isEntity ? Colors.blue : Colors.green,
            size: 20,
          ),
        ),
      ),
    );
  }
} 