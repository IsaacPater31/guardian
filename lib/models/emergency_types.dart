import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

/// Clase centralizada para manejar todos los tipos de emergencia.
/// 7 tipos activos mapeados en el menú radial de swipe.
class EmergencyTypes {
  /// Mapa con los 7 tipos de emergencia activos y sus configuraciones.
  /// La dirección 'left' no tiene mapeo — queda sin label en el radial menu.
  /// [defaultCommunityKeyword] — substring (en mayúsculas) del nombre de la
  /// comunidad que se pre-selecciona por defecto al enviar este tipo de alerta.
  /// null = sin comunidad sugerida (el usuario debe configurarla en Ajustes).
  static const Map<String, Map<String, dynamic>> types = {
    'up': {
      'type': 'HEALTH',
      'icon': Icons.local_hospital,
      'color': Color(0xFF26C6DA),
      'defaultCommunityKeyword': null,
    },
    'upLeft': {
      'type': 'HOME_HELP',
      'icon': Icons.home,
      'color': Color(0xFF66BB6A),
      'defaultCommunityKeyword': null,
    },
    'upRight': {
      'type': 'POLICE',
      'icon': Icons.local_police,
      'color': Color(0xFF1565C0),
      'defaultCommunityKeyword': 'POLICIA',
    },
    'right': {
      'type': 'FIRE',
      'icon': Icons.local_fire_department,
      'color': Color(0xFFE53935),
      'defaultCommunityKeyword': 'BOMBEROS',
    },
    'downRight': {
      'type': 'ACCOMPANIMENT',
      'icon': Icons.people,
      'color': Color(0xFF8E24AA),
      'defaultCommunityKeyword': null,
    },
    'down': {
      'type': 'ENVIRONMENTAL',
      'icon': Icons.nature_people,
      'color': Color(0xFF43A047),
      'defaultCommunityKeyword': 'AMBIENTAL',
    },
    'downLeft': {
      'type': 'ROAD_EMERGENCY',
      'icon': Icons.directions_car,
      'color': Color(0xFFFF7043),
      'defaultCommunityKeyword': 'TRANSITO',
    },
  };

  // ── Compatibilidad histórica: getIcon / getColor cubren tipos viejos ──────

  /// Obtiene el ícono correspondiente a un tipo de alerta (nuevos + históricos)
  static IconData getIcon(String alertType) {
    switch (alertType) {
      // Nuevos tipos activos
      case 'HEALTH':          return Icons.local_hospital;
      case 'HOME_HELP':       return Icons.home;
      case 'POLICE':          return Icons.local_police;
      case 'FIRE':            return Icons.local_fire_department;
      case 'ACCOMPANIMENT':   return Icons.people;
      case 'ENVIRONMENTAL':   return Icons.nature_people;
      case 'ROAD_EMERGENCY':  return Icons.directions_car;
      // Tipos históricos (para mostrar alertas antiguas en feed/mapa)
      case 'ROBBERY':                    return Icons.person_off;
      case 'ACCIDENT':                   return Icons.car_crash;
      case 'UNSAFETY':                   return Icons.warning;
      case 'PHYSICAL RISK':              return Icons.accessibility;
      case 'PUBLIC SERVICES EMERGENCY':  return Icons.construction;
      case 'VIAL EMERGENCY':             return Icons.directions_car;
      case 'ASSISTANCE':                 return Icons.help;
      case 'STREET ESCORT':              return Icons.people;
      case 'EMERGENCY':                  return Icons.emergency;
      default:                           return Icons.warning;
    }
  }

  /// Obtiene el color correspondiente a un tipo de alerta (nuevos + históricos)
  static Color getColor(String alertType) {
    switch (alertType) {
      // Nuevos tipos activos
      case 'HEALTH':          return const Color(0xFF26C6DA);
      case 'HOME_HELP':       return const Color(0xFF66BB6A);
      case 'POLICE':          return const Color(0xFF1565C0);
      case 'FIRE':            return const Color(0xFFE53935);
      case 'ACCOMPANIMENT':   return const Color(0xFF8E24AA);
      case 'ENVIRONMENTAL':   return const Color(0xFF43A047);
      case 'ROAD_EMERGENCY':  return const Color(0xFFFF7043);
      // Tipos históricos
      case 'ROBBERY':                   return const Color(0xFF9C27B0);
      case 'ACCIDENT':
      case 'VIAL EMERGENCY':            return Colors.orange;
      case 'UNSAFETY':                  return Colors.orange;
      case 'PHYSICAL RISK':             return const Color(0xFF673AB7);
      case 'STREET ESCORT':
      case 'ASSISTANCE':                return Colors.blue;
      case 'PUBLIC SERVICES EMERGENCY': return Colors.amber;
      case 'EMERGENCY':                 return Colors.red;
      default:                          return Colors.grey;
    }
  }

  /// Obtiene la configuración completa de un tipo de emergencia por dirección
  static Map<String, dynamic>? getTypeByDirection(String direction) {
    return types[direction];
  }

  /// Obtiene la configuración completa de un tipo por nombre de tipo
  static Map<String, dynamic>? getTypeByName(String typeName) {
    return types.values.cast<Map<String, dynamic>?>().firstWhere(
      (data) => data != null && data['type'] == typeName,
      orElse: () => null,
    );
  }

  /// Devuelve el keyword de comunidad por defecto para un [typeName] (puede ser null).
  /// Este keyword se compara contra el nombre de las comunidades del usuario
  /// para pre-marcar la comunidad más pertinente al enviar la alerta.
  static String? getDefaultCommunityKeyword(String typeName) {
    final entry = types.values.cast<Map<String, dynamic>?>().firstWhere(
      (data) => data != null && data['type'] == typeName,
      orElse: () => null,
    );
    return entry?['defaultCommunityKeyword'] as String?;
  }

  /// Obtiene todas las direcciones disponibles
  static List<String> get allDirections => types.keys.toList();

  /// Obtiene todos los tipos activos (nuevos 7)
  static List<String> get allTypes =>
      types.values.map((data) => data['type'] as String).toList();

  /// Obtiene el tipo de emergencia traducido
  static String getTranslatedType(String type, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return type;

    switch (type) {
      // Nuevos tipos
      case 'HEALTH':         return localizations.emergencyHealth;
      case 'HOME_HELP':      return localizations.emergencyHomeHelp;
      case 'POLICE':         return localizations.emergencyPolice;
      case 'FIRE':           return localizations.emergencyFireNew;
      case 'ACCOMPANIMENT':  return localizations.emergencyAccompaniment;
      case 'ENVIRONMENTAL':  return localizations.emergencyEnvironmental;
      case 'ROAD_EMERGENCY': return localizations.emergencyRoadEmergency;
      // Históricos (para detalle/feed de alertas antiguas)
      case 'STREET ESCORT':              return localizations.emergencyStreetEscort;
      case 'ROBBERY':                    return localizations.emergencyRobbery;
      case 'UNSAFETY':                   return localizations.emergencyUnsafety;
      case 'PHYSICAL RISK':              return localizations.emergencyPhysicalRisk;
      case 'PUBLIC SERVICES EMERGENCY':  return localizations.emergencyPublicServices;
      case 'VIAL EMERGENCY':             return localizations.emergencyVial;
      case 'ASSISTANCE':                 return localizations.emergencyAssistance;
      case 'EMERGENCY':                  return localizations.emergencyGeneral;
      default:                           return type;
    }
  }

  /// Obtiene la config de un tipo por dirección con el nombre ya traducido
  static Map<String, dynamic>? getTypeByDirectionTranslated(
      String direction, BuildContext context) {
    final typeData = types[direction];
    if (typeData == null) return null;
    return {
      ...typeData,
      'type': getTranslatedType(typeData['type'] as String, context),
    };
  }
}
