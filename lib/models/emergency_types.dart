import 'package:flutter/material.dart';
import 'package:guardian/core/alert_detail_catalog.dart';
import 'package:guardian/core/community_icon_catalog.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

/// Clase centralizada para manejar todos los tipos de emergencia.
///
/// El menú radial del home usa solo [types] (6 direcciones). Los tipos
/// `policial` y `ambiental` se eligen con los botones inferiores.
/// [typeMetadata] incluye todos los tipos configurables y filtros.
class EmergencyTypes {
  /// [alertType] guardado en Firestore para alertas de un toque (centro del botón).
  static const String quickAlertType = 'URGENCY';

  /// Metadatos por `alertType` (Firestore): icono y color.
  static const Map<String, Map<String, dynamic>> typeMetadata = {
    AlertDetailCatalog.health: {
      'type': AlertDetailCatalog.health,
      'icon': Icons.medical_services_rounded,
      'color': Color(0xFF26C6DA),
    },
    AlertDetailCatalog.homeHelp: {
      'type': AlertDetailCatalog.homeHelp,
      'icon': Icons.home_rounded,
      'color': Color(0xFF66BB6A),
    },
    AlertDetailCatalog.police: {
      'type': AlertDetailCatalog.police,
      'icon': Icons.local_police_rounded,
      'color': Color(0xFF1565C0),
    },
    AlertDetailCatalog.fire: {
      'type': AlertDetailCatalog.fire,
      'icon': Icons.local_fire_department_rounded,
      'color': Color(0xFFE53935),
    },
    AlertDetailCatalog.securityBreach: {
      'type': AlertDetailCatalog.securityBreach,
      'icon': Icons.security_rounded,
      'color': Color(0xFFC62828),
    },
    AlertDetailCatalog.roadEmergency: {
      'type': AlertDetailCatalog.roadEmergency,
      'icon': Icons.car_crash_rounded,
      'color': Color(0xFFFF7043),
    },
    AlertDetailCatalog.environmental: {
      'type': AlertDetailCatalog.environmental,
      'icon': Icons.thunderstorm_rounded,
      'color': Color(0xFF43A047),
    },
    AlertDetailCatalog.accompaniment: {
      'type': AlertDetailCatalog.accompaniment,
      'icon': Icons.groups_rounded,
      'color': Color(0xFF8E24AA),
    },
    AlertDetailCatalog.harassment: {
      'type': AlertDetailCatalog.harassment,
      'icon': Icons.front_hand_rounded,
      'color': Color(0xFF7B1FA2),
    },
  };

  /// Gesto radial: dirección → tipo (6 direcciones en la estrella).
  /// Arriba-izquierda bomberos, arriba-derecha casa, derecha sanitaria,
  /// izquierda acoso, abajo-izq seguridad, abajo-der vial.
  static const Map<String, String> radialDirectionToType = {
    'upLeft': AlertDetailCatalog.fire,
    'upRight': AlertDetailCatalog.homeHelp,
    'right': AlertDetailCatalog.health,
    'downRight': AlertDetailCatalog.roadEmergency,
    'downLeft': AlertDetailCatalog.securityBreach,
    'left': AlertDetailCatalog.harassment,
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
    final meta = typeMetadata[alertType];
    if (meta != null) return meta['icon'] as IconData;

    switch (alertType) {
      case 'HEALTH':
        return Icons.local_hospital;
      case 'casa':
      case 'HOME_HELP':
        return Icons.home_rounded;
      case 'policial':
      case 'POLICE':
        return Icons.local_police;
      case 'FIRE':
        return Icons.local_fire_department;
      case 'seguridad':
      case 'SECURITY_BREACH':
        return Icons.security_rounded;
      case 'ACCOMPANIMENT':
        return Icons.people;
      case 'ambiental':
      case 'ENVIRONMENTAL':
        return Icons.nature_people;
      case 'vial':
      case 'ROAD_EMERGENCY':
        return Icons.directions_car;
      case 'acoso':
      case 'HARASSMENT':
        return Icons.front_hand_rounded;
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
    final meta = typeMetadata[alertType];
    if (meta != null) return meta['color'] as Color;

    switch (alertType) {
      case 'HEALTH':
        return const Color(0xFF26C6DA);
      case 'casa':
      case 'HOME_HELP':
        return const Color(0xFF66BB6A);
      case 'policial':
      case 'POLICE':
        return const Color(0xFF1565C0);
      case 'FIRE':
        return const Color(0xFFE53935);
      case 'seguridad':
      case 'SECURITY_BREACH':
        return const Color(0xFFC62828);
      case 'ACCOMPANIMENT':
        return const Color(0xFF8E24AA);
      case 'ambiental':
      case 'ENVIRONMENTAL':
        return const Color(0xFF43A047);
      case 'vial':
      case 'ROAD_EMERGENCY':
        return const Color(0xFFFF7043);
      case 'acoso':
      case 'HARASSMENT':
        return const Color(0xFF7B1FA2);
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
      case 'casa':
      case 'HOME_HELP':
        return localizations.emergencyHomeHelp;
      case 'policial':
      case 'POLICE':
        return localizations.emergencyPolice;
      case 'FIRE':
        return localizations.emergencyFireNew;
      case 'seguridad':
      case 'SECURITY_BREACH':
        return localizations.emergencySecurityBreach;
      case 'ACCOMPANIMENT':
        return localizations.emergencyAccompaniment;
      case 'ambiental':
      case 'ENVIRONMENTAL':
        return localizations.emergencyEnvironmental;
      case 'vial':
      case 'ROAD_EMERGENCY':
        return localizations.emergencyRoadEmergency;
      case 'URGENCY':
        return localizations.emergencyUrgency;
      case 'acoso':
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

  /// Label for an alert, preferring denormalized custom entity type names.
  static String labelForAlert({
    required String alertType,
    String? alertTypeLabel,
    required BuildContext context,
  }) {
    final custom = alertTypeLabel?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return getTranslatedType(alertType, context);
  }

  static Color colorForAlert({
    required String alertType,
    String? alertTypeColor,
  }) {
    final hex = alertTypeColor?.trim();
    if (hex != null && hex.isNotEmpty && RegExp(r'^#([0-9a-fA-F]{6})$').hasMatch(hex)) {
      final v = int.parse(hex.substring(1), radix: 16);
      return Color(0xFF000000 | v);
    }
    return getColor(alertType);
  }

  static IconData iconForAlert({
    required String alertType,
    int? alertTypeIconCodePoint,
  }) {
    if (alertTypeIconCodePoint != null && alertTypeIconCodePoint > 0) {
      // Solo IconData const del catálogo (tree-shake friendly en release).
      return CommunityIconCatalog.iconFromCodePoint(alertTypeIconCodePoint);
    }
    return getIcon(alertType);
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
