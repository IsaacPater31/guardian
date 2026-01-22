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
        backgroundColor: Colors.red,
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
                    color: Color(0xFF4CAF50),
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
          backgroundColor: const Color(0xFF4CAF50),
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
          backgroundColor: Colors.red,
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
    final translatedType = EmergencyTypes.getTranslatedType(emergencyType, context);
    
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
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                padding: const EdgeInsets.all(24),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.people,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Seleccionar Comunidades',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Selecciona una o más comunidades',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (selectedCommunityIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${selectedCommunityIds.length} seleccionada${selectedCommunityIds.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
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
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isSelected 
                                ? Colors.blue.withValues(alpha: 0.1)
                                : Colors.white,
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isEntity 
                                      ? Colors.blue.withValues(alpha: 0.1)
                                      : Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isEntity ? Icons.shield : Icons.people,
                                  color: isEntity ? Colors.blue : Colors.green,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                community['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.blue : Colors.black,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (community['description'] != null)
                                    Text(
                                      community['description'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (isEntity) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Entidad Oficial',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
                                activeColor: Colors.blue,
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
                    const SizedBox(height: 16),
                    // Botones
                    Row(
                      children: [
                        // Botón Cancelar
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.cancel,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Botón Continuar
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  selectedCommunityIds.isNotEmpty 
                                      ? Colors.blue 
                                      : Colors.grey,
                                  selectedCommunityIds.isNotEmpty 
                                      ? Colors.blue.withValues(alpha: 0.8)
                                      : Colors.grey.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: (selectedCommunityIds.isNotEmpty 
                                      ? Colors.blue 
                                      : Colors.grey).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: selectedCommunityIds.isNotEmpty ? () {
                                final selected = communities
                                    .where((c) => selectedCommunityIds.contains(c['id']))
                                    .toList();
                                Navigator.of(context).pop(selected);
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Continuar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = MediaQuery.of(context).size.height;
            final maxHeight = screenHeight * 0.8;
            
            return Container(
              constraints: BoxConstraints(
                maxHeight: maxHeight,
                maxWidth: constraints.maxWidth * 0.9,
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
                          // Volver a mostrar diálogo de selección
                          _showEmergencyDialog(emergencyType);
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
                        width: 48,
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
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.red,
                                width: 2.5,
                              ),
                            ),
                            child: Icon(
                              emergencyData['icon'],
                              color: Colors.red,
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
                              color: const Color(0xFFF0F7FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF2196F3).withValues(alpha: 0.2),
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
                                        color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.people,
                                        color: Color(0xFF2196F3),
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
                                          color: Color(0xFF1976D2),
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
                                                    ? const Color(0xFF2196F3).withValues(alpha: 0.1)
                                                    : const Color(0xFF4CAF50).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                isEntity ? Icons.shield : Icons.people,
                                                color: isEntity ? const Color(0xFF2196F3) : const Color(0xFF4CAF50),
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
                                              color: const Color(0xFF4CAF50),
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
                              color: const Color(0xFFFFF8E1),
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
                                    color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFFF9800),
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
                    Row(
                      children: [
                        // Botón Cancelar
                        Expanded(
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
                        
                        SizedBox(width: constraints.maxWidth < 400 ? 12 : 16),
                        
                        // Botón Enviar
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: constraints.maxWidth < 400 ? 50 : 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFD32F2F),
                                  Color(0xFFC62828),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.4),
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
    );
  }

  void _showSuccessSnackBar(String emergencyType, List<Map<String, dynamic>> selectedCommunities) async {
    // Use the emergencyType parameter directly - it already contains the correct alert type
    final alertType = emergencyType;
    
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
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
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
                    color: Color(0xFF4CAF50),
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
          backgroundColor: const Color(0xFF4CAF50),
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
          backgroundColor: Colors.red,
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

  String _getDirectionText(Offset offset) {
    final direction = _getDirection(offset);
    switch (direction) {
      case 'up': return 'ARRIBA';
      case 'upLeft': return 'ARRIBA-IZQ';
      case 'left': return 'IZQUIERDA';
      case 'downLeft': return 'ABAJO-IZQ';
      case 'down': return 'ABAJO';
      case 'downRight': return 'ABAJO-DER';
      case 'right': return 'DERECHA';
      case 'upRight': return 'ARRIBA-DER';
      default: return '';
    }
  }









}
