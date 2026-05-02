import 'package:flutter/material.dart';
import 'package:guardian/core/alert_detail_catalog.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

/// Clase centralizada para manejar todos los tipos de emergencia.
///
/// El menú radial del home usa solo [types] (5 direcciones). Los tipos
/// `POLICE` y `ENVIRONMENTAL` se eligen con los botones inferiores.
/// [typeMetadata] incluye todos los tipos configurables y filtros.
class EmergencyTypes {
  /// [alertType] guardado en Firestore para alertas de un toque (centro del botón).
  static const String quickAlertType = 'URGENCY';

  /// Metadatos por `alertType` (Firestore): icono, color, keyword de comunidad.
  static const Map<String, Map<String, dynamic>> typeMetadata = {
    AlertDetailCatalog.health: {
      'type': AlertDetailCatalog.health,
      'icon': Icons.medical_services_rounded,
      'color': Color(0xFF26C6DA),
      'defaultCommunityKeyword': null,
    },
    AlertDetailCatalog.homeHelp: {
      'type': AlertDetailCatalog.homeHelp,
      'icon': Icons.domain_add_rounded,
      'color': Color(0xFF66BB6A),
      'defaultCommunityKeyword': null,
    },
    AlertDetailCatalog.police: {
      'type': AlertDetailCatalog.police,
      'icon': Icons.local_police_rounded,
      'color': Color(0xFF1565C0),
      'defaultCommunityKeyword': 'POLICIA',
    },
    AlertDetailCatalog.fire: {
      'type': AlertDetailCatalog.fire,
      'icon': Icons.shield_moon_rounded,
      'color': Color(0xFFE53935),
      'defaultCommunityKeyword': 'BOMBEROS',
    },
    AlertDetailCatalog.roadEmergency: {
      'type': AlertDetailCatalog.roadEmergency,
      'icon': Icons.car_crash_rounded,
      'color': Color(0xFFFF7043),
      'defaultCommunityKeyword': 'TRANSITO',
    },
    AlertDetailCatalog.environmental: {
      'type': AlertDetailCatalog.environmental,
      'icon': Icons.thunderstorm_rounded,
      'color': Color(0xFF43A047),
      'defaultCommunityKeyword': 'AMBIENTAL',
    },
    AlertDetailCatalog.accompaniment: {
      'type': AlertDetailCatalog.accompaniment,
      'icon': Icons.groups_rounded,
      'color': Color(0xFF8E24AA),
      'defaultCommunityKeyword': null,
    },
    AlertDetailCatalog.harassment: {
      'type': AlertDetailCatalog.harassment,
      'icon': Icons.shield_rounded,
      'color': Color(0xFFEC407A),
      'defaultCommunityKeyword': null,
    },
  };

  /// Gesto radial: dirección → tipo (solo 5 en la estrella, como diseño actual).
  static const Map<String, String> radialDirectionToType = {
    'up': AlertDetailCatalog.harassment,
    'right': AlertDetailCatalog.roadEmergency,
    'downRight': AlertDetailCatalog.fire,
    'downLeft': AlertDetailCatalog.homeHelp,
    'left': AlertDetailCatalog.health,
  };

  /// Mapa dirección → metadata completa (compatibilidad con swipe / UI radial).
  static Map<String, Map<String, dynamic>> get types => {
        for (final e in radialDirectionToType.entries)
          e.key: {
            ...typeMetadata[e.value]!,
            'type': e.value,
          },
      };

  static IconData getIcon(String alertType) {
    switch (alertType) {
      case 'HEALTH':
        return Icons.local_hospital;
      case 'HOME_HELP':
        return Icons.home;
      case 'POLICE':
        return Icons.local_police;
      case 'FIRE':
        return Icons.local_fire_department;
      case 'ACCOMPANIMENT':
        return Icons.people;
      case 'ENVIRONMENTAL':
        return Icons.nature_people;
      case 'ROAD_EMERGENCY':
        return Icons.directions_car;
      case 'HARASSMENT':
        return Icons.shield;
      case 'URGENCY':
        return Icons.emergency;
      case 'ROBBERY':
        return Icons.person_off;
      case 'ACCIDENT':
        return Icons.car_crash;
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
      case 'STREET ESCORT':
        return Icons.people;
      case 'EMERGENCY':
        return Icons.emergency;
      default:
        return Icons.warning;
    }
  }

  static Color getColor(String alertType) {
    switch (alertType) {
      case 'HEALTH':
        return const Color(0xFF26C6DA);
      case 'HOME_HELP':
        return const Color(0xFF66BB6A);
      case 'POLICE':
        return const Color(0xFF1565C0);
      case 'FIRE':
        return const Color(0xFFE53935);
      case 'ACCOMPANIMENT':
        return const Color(0xFF8E24AA);
      case 'ENVIRONMENTAL':
        return const Color(0xFF43A047);
      case 'ROAD_EMERGENCY':
        return const Color(0xFFFF7043);
      case 'HARASSMENT':
        return const Color(0xFFEC407A);
      case 'URGENCY':
        return const Color(0xFFF44336);
      case 'ROBBERY':
        return const Color(0xFF9C27B0);
      case 'ACCIDENT':
      case 'VIAL EMERGENCY':
        return Colors.orange;
      case 'UNSAFETY':
        return Colors.orange;
      case 'PHYSICAL RISK':
        return const Color(0xFF673AB7);
      case 'STREET ESCORT':
      case 'ASSISTANCE':
        return Colors.blue;
      case 'PUBLIC SERVICES EMERGENCY':
        return Colors.amber;
      case 'EMERGENCY':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static Map<String, dynamic>? getTypeByDirection(String direction) {
    return types[direction];
  }

  static Map<String, dynamic>? getTypeByName(String typeName) {
    return typeMetadata[typeName];
  }

  static String? getDefaultCommunityKeyword(String typeName) {
    final meta = typeMetadata[typeName];
    return meta?['defaultCommunityKeyword'] as String?;
  }

  static List<String> get allDirections => types.keys.toList();

  static List<String> get allTypes => AlertDetailCatalog.supportedAlertTypes;

  static List<String> get allTypesForFilters => [
        ...allTypes,
        quickAlertType,
      ];

  static String getTranslatedType(String type, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return type;

    switch (type) {
      case 'HEALTH':
        return localizations.emergencyHealth;
      case 'HOME_HELP':
        return localizations.emergencyHomeHelp;
      case 'POLICE':
        return localizations.emergencyPolice;
      case 'FIRE':
        return localizations.emergencyFireNew;
      case 'ACCOMPANIMENT':
        return localizations.emergencyAccompaniment;
      case 'ENVIRONMENTAL':
        return localizations.emergencyEnvironmental;
      case 'ROAD_EMERGENCY':
        return localizations.emergencyRoadEmergency;
      case 'URGENCY':
        return localizations.emergencyUrgency;
      case 'HARASSMENT':
        return localizations.emergencyHarassment;
      case 'STREET ESCORT':
        return localizations.emergencyStreetEscort;
      case 'ROBBERY':
        return localizations.emergencyRobbery;
      case 'UNSAFETY':
        return localizations.emergencyUnsafety;
      case 'PHYSICAL RISK':
        return localizations.emergencyPhysicalRisk;
      case 'PUBLIC SERVICES EMERGENCY':
        return localizations.emergencyPublicServices;
      case 'VIAL EMERGENCY':
        return localizations.emergencyVial;
      case 'ASSISTANCE':
        return localizations.emergencyAssistance;
      case 'EMERGENCY':
        return localizations.emergencyGeneral;
      default:
        return type;
    }
  }

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
