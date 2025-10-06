import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async'; // Added for Timer
import 'package:guardian/controllers/alert_controller.dart';
import 'package:guardian/models/emergency_types.dart';

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
            const Text('Sending quick alert...'),
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
                      const Text(
                        'Quick Alert Sent',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'Emergency alert has been sent to the community',
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
          content: const Text('Error sending alert. Please try again.'),
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

  void _showEmergencyDialog(String emergencyType) {
    final emergencyData = EmergencyTypes.getTypeByName(emergencyType);
    
    if (emergencyData == null) return; // Salir si no se encuentra el tipo
    
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
            final maxHeight = screenHeight * 0.8; // Máximo 80% de la pantalla
            
            return Container(
              constraints: BoxConstraints(
                maxHeight: maxHeight,
                maxWidth: constraints.maxWidth * 0.9, // Máximo 90% del ancho
              ),
              padding: EdgeInsets.all(
                constraints.maxWidth < 400 ? 16 : 24, // Padding adaptativo
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                                         // Header con ícono y color
                     Container(
                       width: constraints.maxWidth < 400 ? 60 : 80,
                       height: constraints.maxWidth < 400 ? 60 : 80,
                       decoration: BoxDecoration(
                         color: Colors.red.withValues(alpha: 0.1),
                         shape: BoxShape.circle,
                         border: Border.all(
                           color: Colors.red,
                           width: 3,
                         ),
                       ),
                       child: Icon(
                         emergencyData['icon'],
                         color: Colors.red,
                         size: constraints.maxWidth < 400 ? 28 : 36,
                       ),
                     ),
                    
                    SizedBox(height: constraints.maxWidth < 400 ? 16 : 20),
                    
                    // Título
                    Text(
                      emergencyType,
                      style: TextStyle(
                        fontSize: constraints.maxWidth < 400 ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: constraints.maxWidth < 400 ? 8 : 12),
                    
                    // Descripción
                    Text(
                      'Are you sure you want to report this emergency? This will immediately notify the community and nearby guardians.',
                      style: TextStyle(
                        fontSize: constraints.maxWidth < 400 ? 14 : 16,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: constraints.maxWidth < 400 ? 16 : 24),
                    
                    // Información adicional
                    Container(
                      padding: EdgeInsets.all(
                        constraints.maxWidth < 400 ? 12 : 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: const Color(0xFFFF9800),
                            size: constraints.maxWidth < 400 ? 16 : 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This action cannot be undone. The community will be notified immediately.',
                              style: TextStyle(
                                fontSize: constraints.maxWidth < 400 ? 12 : 14,
                                color: const Color(0xFFFF9800),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: constraints.maxWidth < 400 ? 16 : 24),
                    
                    // Botones
                    Row(
                      children: [
                        // Botón Cancelar
                        Expanded(
                          child: Container(
                            height: constraints.maxWidth < 400 ? 48 : 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _hideEmergencyOptions();
                              },
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: constraints.maxWidth < 400 ? 12 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(width: constraints.maxWidth < 400 ? 12 : 16),
                        
                                                 // Botón Reportar
                         Expanded(
                           child: Container(
                             height: constraints.maxWidth < 400 ? 48 : 50,
                             decoration: BoxDecoration(
                               gradient: LinearGradient(
                                 colors: [
                                   Colors.red,
                                   Colors.red.withValues(alpha: 0.8),
                                 ],
                                 begin: Alignment.topLeft,
                                 end: Alignment.bottomRight,
                               ),
                               borderRadius: BorderRadius.circular(12),
                               boxShadow: [
                                 BoxShadow(
                                   color: Colors.red.withValues(alpha: 0.3),
                                   blurRadius: 8,
                                   offset: const Offset(0, 4),
                                 ),
                               ],
                             ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _hideEmergencyOptions();
                                _showSuccessSnackBar(emergencyType);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.emergency,
                                    color: Colors.white,
                                    size: constraints.maxWidth < 400 ? 14 : 18,
                                  ),
                                  SizedBox(width: constraints.maxWidth < 400 ? 4 : 6),
                                  Flexible(
                                    child: Text(
                                      'Send Alert',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: constraints.maxWidth < 400 ? 12 : 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
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
      ),
    );
  }

  void _showSuccessSnackBar(String emergencyType) async {
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
            const Text('Sending swiped alert...'),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
      ),
    );

    final success = await _alertController.sendSwipedAlert(
      alertType: alertType,
      isAnonymous: false, // Swiped alerts are never anonymous
    );

    ScaffoldMessenger.of(context).clearSnackBars();

    if (success) {
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
                      const Text(
                        'Report Sent',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'Emergency has been reported to the community',
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
          content: const Text('Error sending alert. Please try again.'),
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
                    indicatorSize = screenWidth * 0.28; // Un poco más pequeño que el botón principal
                  } else if (screenWidth < 600) {
                    indicatorSize = screenWidth * 0.25;
                  } else if (screenWidth < 900) {
                    indicatorSize = screenWidth * 0.2;
                  } else {
                    indicatorSize = screenWidth * 0.16;
                  }
                  
                  indicatorSize = indicatorSize.clamp(120.0, 200.0);
                  
                  return Container(
                    width: indicatorSize,
                    height: indicatorSize,
                    decoration: BoxDecoration(
                      color: _showDragFeedback 
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _showDragFeedback ? Colors.red : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: _showDragFeedback && _currentDragDirection != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                EmergencyTypes.getTypeByDirection(_currentDragDirection!)?['icon'] ?? Icons.warning,
                                color: Colors.red,
                                size: indicatorSize * 0.15,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                EmergencyTypes.getTypeByDirection(_currentDragDirection!)?['type'] ?? 'UNKNOWN',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: indicatorSize * 0.08,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : Text(
                            'DRAG',
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
                    final screenHeight = screenSize.height;
                    
                    // Calcular tamaño del botón basado en la pantalla completa
                    double buttonSize;
                    
                    if (screenWidth < 400) {
                      // Pantallas pequeñas (teléfonos compactos)
                      buttonSize = screenWidth * 0.4;
                    } else if (screenWidth < 600) {
                      // Pantallas medianas (teléfonos normales)
                      buttonSize = screenWidth * 0.35;
                    } else if (screenWidth < 900) {
                      // Pantallas grandes (tablets pequeñas)
                      buttonSize = screenWidth * 0.25;
                    } else {
                      // Pantallas muy grandes (tablets grandes)
                      buttonSize = screenWidth * 0.2;
                    }
                    
                    // Asegurar que el botón no sea demasiado pequeño ni demasiado grande
                    buttonSize = buttonSize.clamp(150.0, 300.0);
                    
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
                              "HELP",
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
