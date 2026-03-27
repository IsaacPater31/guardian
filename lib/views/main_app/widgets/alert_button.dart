import 'package:flutter/material.dart';
 
import 'dart:async'; // Added for Timer
import 'package:guardian/controllers/alert_controller.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/services/community_service.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

class AlertButton extends StatefulWidget {
  final VoidCallback onPressed;

  const AlertButton({super.key, required this.onPressed});

  @override
  State<AlertButton> createState() => _AlertButtonState();
}

class _AlertButtonState extends State<AlertButton> with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF007AFF);
  static const Color _primaryDark = Color(0xFF1C1C1E);
  static const Color _danger = Color(0xFFFF3B30);
  static const Color _surface = Color(0xFFF8F9FA);

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  bool _showEmergencyOptions = false;
  String _currentEmergencyType = '';
  bool _isGestureActive = false;
  
  // Variables para mostrar el desplazamiento
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  
  // Variables para feedback visual en tiempo real
  String? _currentDragDirection;
  bool _showDragFeedback = false;
  
  // Instancia del controlador de alertas
  final AlertController _alertController = AlertController();
  final CommunityService _communityService = CommunityService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleGesture(String direction) {
    if (EmergencyTypes.types.containsKey(direction) && !_isGestureActive) {
      _isGestureActive = true;
      setState(() {
        _currentEmergencyType = direction;
        _showEmergencyOptions = true;
      });
      _animationController.forward();
      
      // Mostrar diálogo después de la animación
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _showEmergencyDialog(EmergencyTypes.types[direction]!['type']);
        }
      });
    }
  }

  void _sendQuickAlert() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Text(AppLocalizations.of(context)!.sendingAlert),
          ],
        ),
        backgroundColor: _primaryDark,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );

    final success = await _alertController.sendQuickAlert(
      alertType: 'EMERGENCY',
      isAnonymous: false, // Quick alerts are never anonymous
    );

    ScaffoldMessenger.of(context).clearSnackBars();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: _primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.alertSent,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)!.alertSentToCommunity,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: _primaryDark,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSendingAlert),
          backgroundColor: _danger,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showEmergencyDialog(String emergencyType) async {
    final emergencyData = EmergencyTypes.getTypeByName(emergencyType);
    
    if (emergencyData == null) return; // Salir si no se encuentra el tipo
    
    // Primero mostrar diálogo de selección de comunidades (múltiple)
    final selectedCommunities = await _showCommunitySelectionDialog(emergencyType);
    
    // Si el usuario seleccionó al menos una comunidad, mostrar confirmación
    if (selectedCommunities != null && selectedCommunities.isNotEmpty && mounted) {
      _showFinalConfirmationDialog(emergencyType, selectedCommunities);
    } else {
      _hideEmergencyOptions();
    }
  }

  /// Muestra diálogo para seleccionar comunidades (múltiple selección)
  Future<List<Map<String, dynamic>>?> _showCommunitySelectionDialog(String emergencyType) async {
    if (!mounted) return null;
    
    // Mostrar indicador de carga mientras se obtienen las comunidades
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // Cargar comunidades del usuario
      final communities = await _communityService.getMyCommunities();
      
      // Cerrar indicador de carga
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (communities.isEmpty) {
        // Si no hay comunidades, mostrar error
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No tienes comunidades disponibles'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        return null;
      }

      if (!mounted) return null;

      // Lista de comunidades seleccionadas
      final Set<String> selectedCommunityIds = {};

      // Mostrar diálogo de selección (múltiple, con scroll)
      final selectedCommunities = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            final sw = MediaQuery.of(context).size.width;
            final sh = MediaQuery.of(context).size.height;
            final isSmall = sw < 360;
            final dialogPadding = isSmall ? 14.0 : 20.0;
            final titleFontSize = isSmall ? 16.0 : 20.0;
            final subtitleFontSize = isSmall ? 12.0 : 14.0;

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: isSmall ? 10 : 18,
                vertical: isSmall ? 12 : 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: SafeArea(
                child: Container(
                constraints: BoxConstraints(
                  maxWidth: (sw * 0.95).clamp(0.0, 420.0),
                  maxHeight: sh * (isSmall ? 0.85 : 0.80),
                ),
                padding: EdgeInsets.all(dialogPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSmall ? 6 : 8),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.people,
                            color: _primary,
                            size: isSmall ? 20 : 24,
                          ),
                        ),
                        SizedBox(width: isSmall ? 8 : 12),
                        Expanded(
                          child: Text(
                            'Seleccionar Comunidades',
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: isSmall ? 20 : 24),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: isSmall ? 32 : 40,
                            minHeight: isSmall ? 32 : 40,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmall ? 8 : 12),
                    Text(
                      'Selecciona una o más comunidades',
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (selectedCommunityIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${selectedCommunityIds.length} seleccionada${selectedCommunityIds.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _primary,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: isSmall ? 10 : 14),
                    // Lista de comunidades con scroll
                    Expanded(
                      child: ListView.builder(
                        itemCount: communities.length,
                        itemBuilder: (context, index) {
                          final community = communities[index];
                          final isEntity = community['is_entity'] as bool;
                          final communityId = community['id'] as String;
                          final isSelected = selectedCommunityIds.contains(communityId);

                          return Card(
                            margin: EdgeInsets.only(bottom: isSmall ? 6 : 8),
                            color: isSelected
                                ? _primary.withValues(alpha: 0.10)
                                : Colors.white,
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isSmall ? 10 : 16,
                                vertical: isSmall ? 2 : 4,
                              ),
                              leading: Container(
                                width: isSmall ? 34 : 40,
                                height: isSmall ? 34 : 40,
                                decoration: BoxDecoration(
                                  color: isEntity
                                      ? _primary.withValues(alpha: 0.10)
                                      : const Color(0xFF5AC8FA).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isEntity ? Icons.shield : Icons.people,
                                  color: isEntity ? _primary : const Color(0xFF5AC8FA),
                                  size: isSmall ? 17 : 20,
                                ),
                              ),
                              title: Text(
                                community['name'] ?? '',
                                style: TextStyle(
                                  fontSize: isSmall ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? _primary : _primaryDark,
                                ),
                              ),
                              subtitle: community['description'] != null
                                  ? Text(
                                      community['description'] ?? '',
                                      style: TextStyle(
                                        fontSize: isSmall ? 11 : 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedCommunityIds.add(communityId);
                                    } else {
                                      selectedCommunityIds.remove(communityId);
                                    }
                                  });
                                },
                                activeColor: _primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    selectedCommunityIds.remove(communityId);
                                  } else {
                                    selectedCommunityIds.add(communityId);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: isSmall ? 10 : 14),
                    // Botones
                    Row(
                      children: [
                        // Botón Cancelar
                        Expanded(
                          child: SizedBox(
                            height: isSmall ? 44 : 48,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                'Cancelar',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: isSmall ? 13 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isSmall ? 8 : 12),
                        // Botón Continuar
                        Expanded(
                          child: SizedBox(
                            height: isSmall ? 44 : 48,
                            child: ElevatedButton.icon(
                              onPressed: selectedCommunityIds.isNotEmpty
                                  ? () {
                                      final selected = communities
                                          .where((c) => selectedCommunityIds
                                              .contains(c['id']))
                                          .toList();
                                      Navigator.of(context).pop(selected);
                                    }
                                  : null,
                              icon: Icon(Icons.arrow_forward,
                                  size: isSmall ? 16 : 18),
                              label: Text(
                                'Continuar',
                                style: TextStyle(
                                  fontSize: isSmall ? 13 : 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedCommunityIds.isNotEmpty
                                    ? _primaryDark
                                    : Colors.grey,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              ),
            );
          },
        ),
      );

      return selectedCommunities;
    } catch (e) {
      // Cerrar indicador de carga si hay error
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando comunidades: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return null;
    }
  }

  /// Muestra diálogo de confirmación final con las comunidades seleccionadas
  void _showFinalConfirmationDialog(String emergencyType, List<Map<String, dynamic>> selectedCommunities) {
    final emergencyData = EmergencyTypes.getTypeByName(emergencyType);
    final translatedType = EmergencyTypes.getTranslatedType(emergencyType, context);
    
    if (emergencyData == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width < 360 ? 10 : 18,
          vertical: MediaQuery.of(context).size.width < 360 ? 12 : 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: SafeArea(
          child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = MediaQuery.of(context).size.height;
            final maxHeight = screenHeight * 0.8;
            
            return Container(
              constraints: BoxConstraints(
                maxHeight: maxHeight,
                maxWidth: constraints.maxWidth,
              ),
              padding: EdgeInsets.all(
                constraints.maxWidth < 400 ? 16 : 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header con botón de retroceso
                  Row(
                    children: [
                      // Botón de retroceso
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.grey[700],
                            size: 20,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Volver a mostrar solo la selección
                          _showCommunitySelectionDialog(emergencyType).then((selection) {
                            if (selection != null && selection.isNotEmpty && mounted) {
                              _showFinalConfirmationDialog(emergencyType, selection);
                            } else {
                              _hideEmergencyOptions();
                            }
                          });
                        },
                        tooltip: 'Volver',
                      ),
                      const Spacer(),
                      // Título del header
                      Text(
                        'Confirmar Alerta',
                        style: TextStyle(
                          fontSize: constraints.maxWidth < 400 ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const Spacer(),
                      // Espacio para balancear el layout
                      SizedBox(
                        width: 44,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Contenedor principal con scroll
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header con ícono del tipo de alerta
                          Container(
                            width: constraints.maxWidth < 400 ? 64 : 80,
                            height: constraints.maxWidth < 400 ? 64 : 80,
                            decoration: BoxDecoration(
                              color: _danger.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _danger,
                                width: 2.5,
                              ),
                            ),
                            child: Icon(
                              emergencyData['icon'],
                              color: _danger,
                              size: constraints.maxWidth < 400 ? 30 : 38,
                            ),
                          ),
                          
                          SizedBox(height: constraints.maxWidth < 400 ? 16 : 20),
                          
                          // Título del tipo de alerta
                          Text(
                            translatedType,
                            style: TextStyle(
                              fontSize: constraints.maxWidth < 400 ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          SizedBox(height: constraints.maxWidth < 400 ? 12 : 16),
                    
                          // Comunidades seleccionadas
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _primary.withValues(alpha: 0.18),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: _primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.people,
                                        color: _primary,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Destinatarios (${selectedCommunities.length})',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _primary,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Lista de comunidades seleccionadas con scroll
                                Container(
                                  constraints: BoxConstraints(
                                    maxHeight: screenHeight * 0.25,
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: selectedCommunities.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final community = selectedCommunities[index];
                                      final isEntity = community['is_entity'] as bool;
                                      
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.grey[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: isEntity 
                                                    ? _primary.withValues(alpha: 0.1)
                                                    : const Color(0xFF5AC8FA).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                isEntity ? Icons.shield : Icons.people,
                                                color: isEntity ? _primary : const Color(0xFF5AC8FA),
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    community['name'] ?? '',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF1A1A1A),
                                                      letterSpacing: 0.1,
                                                    ),
                                                  ),
                                                  if (isEntity) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Entidad Oficial',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.check_circle,
                                              color: _primary,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                    
                          SizedBox(height: constraints.maxWidth < 400 ? 20 : 24),
                          
                          // Descripción
                          Text(
                            AppLocalizations.of(context)!.confirmEmergencyReport,
                            style: TextStyle(
                              fontSize: constraints.maxWidth < 400 ? 14 : 15,
                              color: Colors.grey[700],
                              height: 1.5,
                              letterSpacing: 0.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          SizedBox(height: constraints.maxWidth < 400 ? 20 : 24),
                          
                          // Información adicional
                          Container(
                            padding: EdgeInsets.all(
                              constraints.maxWidth < 400 ? 14 : 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5EB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFF9800).withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFFF9500),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(context)!.actionCannotBeUndone,
                                    style: TextStyle(
                                      fontSize: constraints.maxWidth < 400 ? 13 : 14,
                                      color: const Color(0xFFE65100),
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
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
                    
                  SizedBox(height: constraints.maxWidth < 400 ? 16 : 20),
                    
                    // Botones fijos en la parte inferior
                    Wrap(
                      spacing: constraints.maxWidth < 400 ? 10 : 16,
                      runSpacing: constraints.maxWidth < 400 ? 10 : 12,
                      children: [
                        // Botón Cancelar
                        SizedBox(
                          width: constraints.maxWidth < 400
                              ? double.infinity
                              : (constraints.maxWidth * 0.36),
                          child: Container(
                            height: constraints.maxWidth < 400 ? 50 : 52,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1.5,
                              ),
                            ),
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _hideEmergencyOptions();
                              },
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.cancel,
                                style: TextStyle(
                                  color: const Color(0xFF424242),
                                  fontSize: constraints.maxWidth < 400 ? 14 : 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        if (constraints.maxWidth >= 400)
                          SizedBox(width: constraints.maxWidth < 400 ? 12 : 16),
                        
                        // Botón Enviar
                        SizedBox(
                          width: constraints.maxWidth < 400
                              ? double.infinity
                              : (constraints.maxWidth * 0.58),
                          child: Container(
                            height: constraints.maxWidth < 400 ? 50 : 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF007AFF),
                                  Color(0xFF005FCC),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: _primary.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _hideEmergencyOptions();
                                _showSuccessSnackBar(emergencyType, selectedCommunities);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.emergency,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      AppLocalizations.of(context)!.sendAlert,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: constraints.maxWidth < 400 ? 14 : 15,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
          },
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String emergencyType, List<Map<String, dynamic>> selectedCommunities) async {
    // Use the emergencyType parameter directly - it already contains the correct alert type
    final alertType = emergencyType;
    
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Enviando a ${selectedCommunities.length} comunidad${selectedCommunities.length > 1 ? 'es' : ''}...',
              ),
            ),
          ],
        ),
        backgroundColor: _primaryDark,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.fromLTRB(12, 12, 12, (bottomInset + 12).clamp(12.0, 40.0)),
      ),
    );

    // Enviar alerta a cada comunidad seleccionada
    int successCount = 0;
    for (final community in selectedCommunities) {
      final success = await _alertController.sendSwipedAlert(
        alertType: alertType,
        isAnonymous: false, // Swiped alerts are never anonymous
        communityId: community['id'] as String,
      );
      if (success) successCount++;
    }

    ScaffoldMessenger.of(context).clearSnackBars();

    if (successCount > 0) {
      final screenWidth = MediaQuery.of(context).size.width;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF007AFF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.alertSent,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Enviada a $successCount comunidad${successCount > 1 ? 'es' : ''}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: _primaryDark,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(screenWidth < 400 ? 8 : 16),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSendingAlert),
          backgroundColor: _danger,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _hideEmergencyOptions() {
    setState(() {
      _showEmergencyOptions = false;
      _currentEmergencyType = '';
      _isGestureActive = false;
      _isDragging = false;
      _dragOffset = Offset.zero;
      _showDragFeedback = false;
      _currentDragDirection = null;
    });
    _animationController.reverse();
  }

  String _getDirection(Offset offset) {
    final distance = offset.distance;
    
    // Zona central - no mostrar ninguna alerta específica (muy reducida para que aparezca más cerca del centro)
    if (distance < 30) return '';
    
    // Calcular el ángulo en radianes
    final angle = offset.direction;
    final angleDegrees = (angle * 180 / 3.14159 + 360) % 360;
    
    // Dividir en 8 sectores de 45 grados cada uno
    if (angleDegrees >= 337.5 || angleDegrees < 22.5) return 'right';
    if (angleDegrees >= 22.5 && angleDegrees < 67.5) return 'upRight';
    if (angleDegrees >= 67.5 && angleDegrees < 112.5) return 'up';
    if (angleDegrees >= 112.5 && angleDegrees < 157.5) return 'upLeft';
    if (angleDegrees >= 157.5 && angleDegrees < 202.5) return 'left';
    if (angleDegrees >= 202.5 && angleDegrees < 247.5) return 'downLeft';
    if (angleDegrees >= 247.5 && angleDegrees < 292.5) return 'down';
    if (angleDegrees >= 292.5 && angleDegrees < 337.5) return 'downRight';
    
    return '';
  }

  /// Obtiene el color suave para el fondo del círculo de desplazamiento
  /// Usa colores sutiles que no saturan la vista pero permiten distinguir cada tipo
  Color _getSoftBackgroundColor(String? direction) {
    if (direction == null || direction.isEmpty) {
      return Colors.grey.withValues(alpha: 0.2);
    }
    
    final typeData = EmergencyTypes.getTypeByDirection(direction);
    if (typeData == null) {
      return Colors.grey.withValues(alpha: 0.2);
    }
    
    final baseColor = typeData['color'] as Color;
    final typeName = typeData['type'] as String;
    
    // Ajustar alpha según la intensidad del color base
    // Colores más intensos (rojo, amarillo, púrpura) usan alpha más bajo
    double alpha;
    if (typeName == 'FIRE') {
      alpha = 0.15; // Rojo: más sutil
    } else if (typeName == 'ROBBERY') {
      alpha = 0.18; // Púrpura: moderadamente sutil
    } else if (typeName == 'PUBLIC SERVICES EMERGENCY') {
      alpha = 0.16; // Amarillo: más sutil
    } else if (typeName == 'UNSAFETY') {
      alpha = 0.18; // Naranja: moderadamente sutil
    } else {
      alpha = 0.2; // Otros colores: alpha estándar
    }
    
    return baseColor.withValues(alpha: alpha);
  }

  /// Obtiene el color más intenso para el borde y elementos internos
  Color _getIntenseBorderColor(String? direction) {
    if (direction == null || direction.isEmpty) {
      return Colors.grey;
    }
    
    final typeData = EmergencyTypes.getTypeByDirection(direction);
    if (typeData == null) {
      return Colors.grey;
    }
    
    final baseColor = typeData['color'] as Color;
    // Usar el color base con alpha alto para bordes y elementos (0.85-0.95)
    return baseColor.withValues(alpha: 0.9);
  }

  /// Obtiene el color para iconos y texto dentro del círculo
  Color _getContentColor(String? direction) {
    if (direction == null || direction.isEmpty) {
      return Colors.grey[600]!;
    }
    
    final typeData = EmergencyTypes.getTypeByDirection(direction);
    if (typeData == null) {
      return Colors.grey[600]!;
    }
    
    final baseColor = typeData['color'] as Color;
    // Usar el color base con buena opacidad pero no totalmente opaco para suavidad visual
    return baseColor.withValues(alpha: 0.95);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _isDragging = true;
          _dragOffset = Offset.zero;
          _isGestureActive = false;
          _showDragFeedback = false;
          _currentDragDirection = null;
        });
      },
      onPanUpdate: (details) {
        setState(() {
          _dragOffset += details.delta;
        });
        
        // Actualizar feedback visual en tiempo real
        final direction = _getDirection(_dragOffset);
        if (direction != _currentDragDirection) {
          setState(() {
            _currentDragDirection = direction;
            _showDragFeedback = direction.isNotEmpty;
          });
        }
      },
      onPanEnd: (details) {
        // Solo activar si hay una dirección válida
        if (_currentDragDirection != null && _currentDragDirection!.isNotEmpty) {
          _handleGesture(_currentDragDirection!);
        }
        
        setState(() {
          _isDragging = false;
          _dragOffset = Offset.zero;
          _showDragFeedback = false;
          _currentDragDirection = null;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          
          // Indicador de desplazamiento con feedback visual en tiempo real (responsivo)
          if (_isDragging && !_showEmergencyOptions)
            Transform.translate(
              offset: _dragOffset,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calcular tamaño del indicador basado en el botón (más pequeño que el botón principal)
                  final screenSize = MediaQuery.of(context).size;
                  final screenWidth = screenSize.width;
                  
                  double indicatorSize;
                  if (screenWidth < 400) {
                    indicatorSize = screenWidth * 0.34; // Área de desplazamiento más grande
                  } else if (screenWidth < 600) {
                    indicatorSize = screenWidth * 0.3;
                  } else if (screenWidth < 900) {
                    indicatorSize = screenWidth * 0.24;
                  } else {
                    indicatorSize = screenWidth * 0.2;
                  }
                  
                  indicatorSize = indicatorSize.clamp(140.0, 240.0);
                  
                  // Obtener colores según la dirección actual (sutiles y no saturados)
                  final backgroundColor = _getSoftBackgroundColor(_currentDragDirection);
                  final borderColor = _getIntenseBorderColor(_currentDragDirection);
                  final contentColor = _getContentColor(_currentDragDirection);
                  
                  return Container(
                    width: indicatorSize,
                    height: indicatorSize,
                    decoration: BoxDecoration(
                      color: _showDragFeedback 
                        ? backgroundColor
                        : Colors.grey.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _showDragFeedback ? borderColor : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: _showDragFeedback && _currentDragDirection != null
                      ? Stack(
                          children: [
                            Positioned(
                              top: indicatorSize * 0.08,
                              left: 0,
                              right: 0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    EmergencyTypes.getTypeByDirection(_currentDragDirection!)?['icon'] ?? Icons.warning,
                                    color: contentColor,
                                    size: indicatorSize * 0.2,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    EmergencyTypes.getTypeByDirectionTranslated(_currentDragDirection!, context)?['type'] ?? AppLocalizations.of(context)!.unknown,
                                    style: TextStyle(
                                      color: contentColor,
                                      fontSize: indicatorSize * 0.1,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Text(
                            AppLocalizations.of(context)!.drag,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: indicatorSize * 0.12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                  );
                },
              ),
            ),
          
          // Botón principal HELP completamente responsivo
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _showEmergencyOptions ? _scaleAnimation.value : 1.0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Obtener dimensiones de la pantalla
                    final screenSize = MediaQuery.of(context).size;
                    final screenWidth = screenSize.width;
                    // final screenHeight = screenSize.height; // not used
                    
                    // Calcular tamaño del botón basado en la pantalla completa
                    double buttonSize;
                    
                    if (screenWidth < 400) {
                      // Pantallas pequeñas (teléfonos compactos)
                      buttonSize = screenWidth * 0.34;
                    } else if (screenWidth < 600) {
                      // Pantallas medianas (teléfonos normales)
                      buttonSize = screenWidth * 0.3;
                    } else if (screenWidth < 900) {
                      // Pantallas grandes (tablets pequeñas)
                      buttonSize = screenWidth * 0.22;
                    } else {
                      // Pantallas muy grandes (tablets grandes)
                      buttonSize = screenWidth * 0.18;
                    }
                    
                    // Asegurar que el botón no sea demasiado pequeño ni demasiado grande
                    buttonSize = buttonSize.clamp(120.0, 240.0);
                    
                    return Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: buttonSize * 0.15,
                            spreadRadius: buttonSize * 0.05,
                            offset: Offset(0, buttonSize * 0.05),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _sendQuickAlert,
                          borderRadius: BorderRadius.circular(buttonSize / 2),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context)!.help,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: buttonSize * 0.18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          
          // Opciones de emergencia que aparecen con animación (responsivo)
          if (_showEmergencyOptions && _currentEmergencyType.isNotEmpty)
            AnimatedBuilder(
              animation: _opacityAnimation,
              builder: (context, child) {
                final emergencyData = EmergencyTypes.getTypeByDirection(_currentEmergencyType);
                if (emergencyData == null) return const SizedBox.shrink();
                 return Opacity(
                   opacity: _opacityAnimation.value,
                   child: LayoutBuilder(
                     builder: (context, constraints) {
                       // Calcular tamaño responsivo del botón de emergencia específica
                       final screenSize = MediaQuery.of(context).size;
                       final screenWidth = screenSize.width;
                       
                       double emergencyButtonSize;
                       if (screenWidth < 400) {
                         emergencyButtonSize = screenWidth * 0.3;
                       } else if (screenWidth < 600) {
                         emergencyButtonSize = screenWidth * 0.25;
                       } else if (screenWidth < 900) {
                         emergencyButtonSize = screenWidth * 0.18;
                       } else {
                         emergencyButtonSize = screenWidth * 0.15;
                       }
                       
                       emergencyButtonSize = emergencyButtonSize.clamp(120.0, 200.0);
                       
                       return Container(
                         width: emergencyButtonSize,
                         height: emergencyButtonSize,
                         decoration: BoxDecoration(
                           color: Colors.red,
                           shape: BoxShape.circle,
                           boxShadow: [
                             BoxShadow(
                               color: Colors.red.withValues(alpha: 0.4),
                               blurRadius: emergencyButtonSize * 0.15,
                               spreadRadius: emergencyButtonSize * 0.05,
                               offset: Offset(0, emergencyButtonSize * 0.05),
                             ),
                           ],
                         ),
                         child: Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Icon(
                               emergencyData['icon'],
                               color: Colors.white,
                               size: emergencyButtonSize * 0.2,
                             ),
                             SizedBox(height: emergencyButtonSize * 0.05),
                             Text(
                               emergencyData['type'],
                               textAlign: TextAlign.center,
                               style: TextStyle(
                                 color: Colors.white,
                                 fontSize: emergencyButtonSize * 0.08,
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                           ],
                         ),
                       );
                     },
                   ),
                 );
               },
             ),
        ],
      ),
    );
  }

}
