import 'package:flutter/material.dart';

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

  void _showEmergencyDialog(String emergencyType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(emergencyType),
        content: Text('¿Estás seguro de que quieres reportar una emergencia de $emergencyType?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _hideEmergencyOptions();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _hideEmergencyOptions();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('¡Emergencia de $emergencyType reportada!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reportar', style: TextStyle(color: Colors.white)),
          ),
        ],
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
        setState(() {
          _isDragging = true;
          _dragOffset = Offset.zero;
          _isGestureActive = false;
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
                  color: Colors.red.withOpacity(0.3),
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
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onPressed,
                      borderRadius: BorderRadius.circular(90),
                      child: const Center(
                        child: Text(
                          "HELP",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
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
                      color: emergencyData['color'],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: emergencyData['color'].withOpacity(0.3),
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
}
