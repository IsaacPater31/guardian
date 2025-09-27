import 'package:flutter/material.dart';

/// Clase centralizada para manejar todos los tipos de emergencia
/// Elimina la duplicación de datos entre AlertButton y HomeView
class EmergencyTypes {
  /// Mapa con todos los tipos de emergencia y sus configuraciones
  static const Map<String, Map<String, dynamic>> types = {
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

  /// Obtiene el ícono correspondiente a un tipo de alerta
  static IconData getIcon(String alertType) {
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

  /// Obtiene el color correspondiente a un tipo de alerta
  static Color getColor(String alertType) {
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

  /// Obtiene la configuración completa de un tipo de emergencia por dirección
  static Map<String, dynamic>? getTypeByDirection(String direction) {
    return types[direction];
  }

  /// Obtiene la configuración completa de un tipo de emergencia por nombre
  static Map<String, dynamic>? getTypeByName(String typeName) {
    return types.values.firstWhere(
      (data) => data['type'] == typeName,
      orElse: () => <String, dynamic>{},
    );
  }

  /// Obtiene todas las direcciones disponibles
  static List<String> get allDirections => types.keys.toList();

  /// Obtiene todos los tipos de emergencia disponibles
  static List<String> get allTypes => types.values.map((data) => data['type'] as String).toList();
}
