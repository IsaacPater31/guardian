import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async'; // Added for Timer

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
  
  // Variables para long press
  bool _isLongPressing = false;
  Timer? _longPressTimer;
  
  // Variables para alerta detallada
  List<File> _selectedImages = [];
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  // Variables para checkboxes
  bool _shareLocation = true;
  bool _anonymousAlert = false;

  final Map<String, Map<String, dynamic>> _emergencyTypes = {
    'up': {
      'type': 'STREET ESCORT',
      'icon': Icons.people,
      'color': Colors.blue,
    },
    'upLeft': {
      'type': 'ROBBERY',
      'icon': Icons.person_off,
      'color': Colors.red,
    },
    'left': {
      'type': 'UNSAFETY',
      'icon': Icons.person,
      'color': Colors.orange,
    },
    'downLeft': {
      'type': 'PHYSICAL RISK',
      'icon': Icons.accessible,
      'color': Colors.purple,
    },
    'down': {
      'type': 'PUBLIC SERVICES EMERGENCY',
      'icon': Icons.construction,
      'color': Colors.yellow,
    },
    'downRight': {
      'type': 'VIAL EMERGENCY',
      'icon': Icons.directions_car,
      'color': Colors.cyan,
    },
    'right': {
      'type': 'ASSISTANCE',
      'icon': Icons.help,
      'color': Colors.green,
    },
    'upRight': {
      'type': 'FIRE',
      'icon': Icons.local_fire_department,
      'color': Colors.red,
    },
  };

  // --- Declarar variable de estado para el tipo de alerta seleccionado en el formulario detallado ---
  String? _selectedDetailedAlertType;

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
    _descriptionController.dispose();
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _handleGesture(String direction) {
    if (_emergencyTypes.containsKey(direction) && !_isGestureActive) {
      _isGestureActive = true;
      setState(() {
        _currentEmergencyType = direction;
        _showEmergencyOptions = true;
      });
      _animationController.forward();
      
      // Mostrar diálogo después de la animación
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _showEmergencyDialog(_emergencyTypes[direction]!['type']);
        }
      });
    }
  }

  void _sendQuickAlert() {
    // Enviar alerta rápida sin especificar tipo
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
                  Icons.emergency,
                  color: Colors.red,
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

  void _showEmergencyDialog(String emergencyType) {
    final emergencyData = _emergencyTypes.values.firstWhere(
      (data) => data['type'] == emergencyType,
    );
    
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
                              child: Flexible(
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
                              child: Flexible(
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

  void _showSuccessSnackBar(String emergencyType) {
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
  }

  void _hideEmergencyOptions() {
    setState(() {
      _showEmergencyOptions = false;
      _currentEmergencyType = '';
      _isGestureActive = false;
      _isDragging = false;
      _dragOffset = Offset.zero;
    });
    _animationController.reverse();
  }

  String _getDirection(Offset offset) {
    final dx = offset.dx;
    final dy = offset.dy;
    final distance = offset.distance;
    
    if (distance < 50) return '';
    
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
        // Cancelar long press si empieza a arrastrar
        _longPressTimer?.cancel();
        setState(() {
          _isDragging = true;
          _dragOffset = Offset.zero;
          _isGestureActive = false;
          _isLongPressing = false;
        });
      },
      onPanUpdate: (details) {
        setState(() {
          _dragOffset += details.delta;
        });
        
        if (!_showEmergencyOptions && !_isGestureActive) {
          final direction = _getDirection(_dragOffset);
          if (direction.isNotEmpty) {
            _handleGesture(direction);
          }
        }
      },
      onPanEnd: (details) {
        setState(() {
          _isDragging = false;
          _dragOffset = Offset.zero;
        });
      },
      onLongPressStart: (details) {
        _startLongPress();
      },
      onLongPressEnd: (details) {
        _endLongPress();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Indicador de desplazamiento
          if (_isDragging && !_showEmergencyOptions)
            Transform.translate(
              offset: _dragOffset,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Center(
                  child: Text(
                    _getDirectionText(_dragOffset),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          
          // Botón principal HELP (más grande)
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _showEmergencyOptions ? _scaleAnimation.value : 1.0,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLongPressing ? null : _sendQuickAlert,
                      borderRadius: BorderRadius.circular(90),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "HELP",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                              ),
                            ),
                            if (_isLongPressing)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  "Hold for detailed alert",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
                     // Opciones de emergencia que aparecen con animación
           if (_showEmergencyOptions && _currentEmergencyType.isNotEmpty)
             AnimatedBuilder(
               animation: _opacityAnimation,
               builder: (context, child) {
                 final emergencyData = _emergencyTypes[_currentEmergencyType]!;
                 return Opacity(
                   opacity: _opacityAnimation.value,
                   child: Container(
                     width: 140,
                     height: 140,
                     decoration: BoxDecoration(
                       color: Colors.red,
                       shape: BoxShape.circle,
                       boxShadow: [
                         BoxShadow(
                           color: Colors.red.withValues(alpha: 0.3),
                           blurRadius: 15,
                           spreadRadius: 5,
                         ),
                       ],
                     ),
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(
                           emergencyData['icon'],
                           color: Colors.white,
                           size: 32,
                         ),
                         const SizedBox(height: 8),
                         Text(
                           emergencyData['type'],
                           textAlign: TextAlign.center,
                           style: const TextStyle(
                             color: Colors.white,
                             fontSize: 14,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                       ],
                     ),
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

  void _startLongPress() {
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_isDragging && !_showEmergencyOptions) {
        setState(() {
          _isLongPressing = true;
        });
        _showDetailedAlertDialog();
      }
    });
  }

  void _endLongPress() {
    _longPressTimer?.cancel();
    setState(() {
      _isLongPressing = false;
    });
  }

  void _showDetailedAlertDialog() {
    // Al abrir el formulario, si hay tipo de alerta por drag, se preselecciona, si no, queda vacío
    _selectedDetailedAlertType = _currentEmergencyType.isNotEmpty ? _currentEmergencyType : null;
    
    // Variables locales para el estado del diálogo
    bool shareLocation = _shareLocation;
    bool anonymousAlert = _anonymousAlert;
    String? selectedType = _selectedDetailedAlertType;
    final TextEditingController descriptionController = TextEditingController(text: _descriptionController.text);
    List<File> selectedImages = List.from(_selectedImages);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = MediaQuery.of(context).size.height;
              final maxHeight = screenHeight * 0.92;
              
              return Container(
                constraints: BoxConstraints(
                  maxHeight: maxHeight,
                  maxWidth: constraints.maxWidth * 0.92,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header profesional con colores de la app
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Icono con diseño profesional
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.emergency,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Título con tipografía profesional
                          const Text(
                            'Report Emergency',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Subtítulo profesional
                          Text(
                            'Help keep our community safe by providing detailed information',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    // Contenido scrolleable con espaciado profesional
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Tipo de emergencia con diseño profesional
                            _buildEmergencyTypeSection(selectedType, (value) {
                              setDialogState(() {
                                selectedType = value;
                              });
                            }),
                            
                            const SizedBox(height: 24),
                            
                            // 2. Descripción con diseño profesional
                            _buildDescriptionSection(descriptionController),
                            
                            const SizedBox(height: 24),
                            
                            // 3. Configuración de privacidad con diseño profesional
                            _buildPrivacySettingsSection(
                              shareLocation,
                              anonymousAlert,
                              (value) {
                                setDialogState(() {
                                  shareLocation = value ?? false;
                                });
                              },
                              (value) {
                                setDialogState(() {
                                  anonymousAlert = value ?? false;
                                });
                              },
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // 4. Foto con diseño profesional
                            _buildPhotoSection(selectedImages, (images) {
                              setDialogState(() {
                                selectedImages = images;
                              });
                            }),
                            
                            // Espacio adicional al final
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    
                    // Botones con diseño profesional
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  // Actualizar el estado principal con los valores del diálogo
                                  setState(() {
                                    _selectedDetailedAlertType = selectedType;
                                    _descriptionController.text = descriptionController.text;
                                    _shareLocation = shareLocation;
                                    _anonymousAlert = anonymousAlert;
                                    _selectedImages = selectedImages;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFF3F4F6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  // Actualizar el estado principal y enviar la alerta
                                  setState(() {
                                    _selectedDetailedAlertType = selectedType;
                                    _descriptionController.text = descriptionController.text;
                                    _shareLocation = shareLocation;
                                    _anonymousAlert = anonymousAlert;
                                    _selectedImages = selectedImages;
                                  });
                                  _sendDetailedAlert();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1F2937),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Send Alert',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
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

  Widget _buildEmergencyTypeSection(String? selectedType, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de sección profesional
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.category_rounded,
                color: Color(0xFF1F2937),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Emergency Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Dropdown con diseño profesional
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selectedType != null ? const Color(0xFF1F2937).withValues(alpha: 0.3) : const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: selectedType,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Select emergency type',
              labelStyle: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: const Text(
                  'Choose emergency type',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                ),
              ),
              ..._emergencyTypes.entries.map((entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        entry.value['icon'],
                        color: const Color(0xFF1F2937),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value['type'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F2937),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
            ],
            onChanged: onChanged,
            dropdownColor: Colors.white,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1F2937),
            ),
            icon: const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de sección profesional
        Row(
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
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Optional',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // TextField con diseño profesional
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF1F2937),
            ),
            decoration: InputDecoration(
              hintText: 'Describe what happened, location details, and any relevant information...',
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counter: Container(
                padding: const EdgeInsets.only(top: 8, right: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${controller.text.length}/500',
                      style: TextStyle(
                        color: controller.text.length > 450 ? const Color(0xFFF59E0B) : const Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            onChanged: (value) {
              if (value.length > 500) {
                controller.text = value.substring(0, 500);
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: 500),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySettingsSection(bool shareLocation, bool anonymousAlert, ValueChanged<bool?> onShareLocationChanged, ValueChanged<bool?> onAnonymousChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de sección profesional
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.privacy_tip_rounded,
                color: Color(0xFF1F2937),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Privacy Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Location sharing con diseño profesional
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: shareLocation ? const Color(0xFFF0F9FF) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: shareLocation ? const Color(0xFF1F2937).withValues(alpha: 0.2) : const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: shareLocation ? const Color(0xFF1F2937).withValues(alpha: 0.1) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: shareLocation ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Location',
                      style: TextStyle(
                        color: shareLocation ? const Color(0xFF1F2937) : const Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shareLocation 
                        ? 'Your current location will be included in the alert'
                        : 'Location sharing is disabled for this alert',
                      style: TextStyle(
                        color: shareLocation ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.1,
                child: Checkbox(
                  value: shareLocation,
                  onChanged: onShareLocationChanged,
                  activeColor: const Color(0xFF1F2937),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Anonymous alert con diseño profesional
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: anonymousAlert ? const Color(0xFFF0F9FF) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: anonymousAlert ? const Color(0xFF1F2937).withValues(alpha: 0.2) : const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: anonymousAlert ? const Color(0xFF1F2937).withValues(alpha: 0.1) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.visibility_off_rounded,
                  color: anonymousAlert ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anonymous Report',
                      style: TextStyle(
                        color: anonymousAlert ? const Color(0xFF1F2937) : const Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      anonymousAlert 
                        ? 'Your identity will be hidden from other users'
                        : 'Your profile will be visible to the community',
                      style: TextStyle(
                        color: anonymousAlert ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.1,
                child: Checkbox(
                  value: anonymousAlert,
                  onChanged: onAnonymousChanged,
                  activeColor: const Color(0xFF1F2937),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

         Widget _buildPhotoSection(List<File> selectedImages, ValueChanged<List<File>> onImagesChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de sección profesional
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFF1F2937),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Photo Evidence',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Optional',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Imágenes seleccionadas con diseño profesional
        if (selectedImages.isNotEmpty)
          Column(
            children: selectedImages.map((image) {
              return Container(
                width: double.infinity,
                height: 180,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.file(
                        image,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                      // Overlay sutil para mejor legibilidad del botón
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [
                                Colors.black.withValues(alpha: 0.2),
                                Colors.transparent,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Botón de eliminar profesional
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            selectedImages.remove(image);
                            onImagesChanged(selectedImages);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        
        // Contador de fotos
        if (selectedImages.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${selectedImages.length} photo${selectedImages.length == 1 ? '' : 's'} selected',
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        
        // Opciones de selección de imagen profesionales (siempre visibles)
        if (selectedImages.length < 3)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    try {
                      final XFile? image = await _picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 80,
                      );
                      
                      if (image != null) {
                        selectedImages.add(File(image.path));
                        onImagesChanged(selectedImages);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error picking image: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Color(0xFF1F2937),
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Take Photo',
                          style: TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Use camera',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    try {
                      final XFile? image = await _picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 80,
                      );
                      if (image != null) {
                        selectedImages.add(File(image.path));
                        onImagesChanged(selectedImages);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error seleccionando imagen: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.photo_library_rounded,
                            color: Color(0xFF1F2937),
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gallery',
                          style: TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Choose existing',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          // Mensaje cuando se alcanza el límite de fotos
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: const Color(0xFFFF9800),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Maximum 3 photos allowed',
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFFFF9800),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error seleccionando imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearForm() {
    setState(() {
      _selectedImages = [];
      _descriptionController.clear();
      _shareLocation = true;
      _anonymousAlert = false;
    });
  }

  void _sendDetailedAlert() {
    // TODO: Implementar envío a Firebase con datos detallados
    final description = _descriptionController.text.trim();
    final hasImage = _selectedImages.isNotEmpty;
    
    // Construir mensaje de confirmación
    String confirmationMessage = 'Emergency reported';
    if (hasImage) {
      if (_selectedImages.length == 1) {
        confirmationMessage += ' with photo';
      } else {
        confirmationMessage += ' with ${_selectedImages.length} photos';
      }
    }
    if (description.isNotEmpty) confirmationMessage += hasImage ? ' and description' : ' with description';
    if (_shareLocation) confirmationMessage += ' and location';
    if (_anonymousAlert) confirmationMessage += ' (anonymous)';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
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
                    'Detailed Alert Sent',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    confirmationMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
    
    _clearForm();
  }
}
