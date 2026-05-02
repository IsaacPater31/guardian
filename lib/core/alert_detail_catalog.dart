import 'package:flutter/material.dart';

/// Defines alert categories and subtype options for the swipe flow.
///
/// This catalog is intentionally local and editable so product/operations can
/// add, remove, or rename categories/subtypes without rewriting UI logic.
///
/// Web parity: use the same `alertType` / subtype `id` strings as in the webapp
/// (`src/config/alertTypes.js`, `src/utils/alertSubtype.js`) so Firestore reads match both clients.
class AlertDetailCatalog {
  static const String health = 'HEALTH';
  static const String homeHelp = 'HOME_HELP';
  static const String police = 'POLICE';
  static const String fire = 'FIRE';
  /// Brecha de seguridad (física, perimetral, sistemas, etc.) — distinto de bomberos/incendio.
  static const String securityBreach = 'SECURITY_BREACH';
  static const String roadEmergency = 'ROAD_EMERGENCY';
  static const String environmental = 'ENVIRONMENTAL';
  static const String accompaniment = 'ACCOMPANIMENT';
  static const String harassment = 'HARASSMENT';
  static const String otherSubtypeId = 'OTHER';

  static const List<String> supportedAlertTypes = [
    health,
    homeHelp,
    police,
    fire,
    securityBreach,
    roadEmergency,
    environmental,
    accompaniment,
    harassment,
  ];

  static const Map<String, AlertCategoryDetailConfig> categories = {
    health: AlertCategoryDetailConfig(
      alertType: health,
      fallbackTitle: 'Sanitarias',
      subtypes: [
        AlertSubtypeOption(id: 'FIRST_AID', label: 'Primeros auxilios'),
        AlertSubtypeOption(id: 'MEDICATIONS', label: 'Medicamentos'),
        AlertSubtypeOption(id: 'AMBULANCE', label: 'Ambulancia'),
        AlertSubtypeOption(id: 'MENTAL_HEALTH', label: 'Salud mental'),
        AlertSubtypeOption(id: 'NEED_DOCTOR', label: 'Necesito medico'),
        AlertSubtypeOption(id: otherSubtypeId, label: 'Otro', requiresDetail: true),
      ],
    ),
    homeHelp: AlertCategoryDetailConfig(
      alertType: homeHelp,
      fallbackTitle: 'Ayuda en casa',
      subtypes: [
        AlertSubtypeOption(id: 'GAS_LEAK', label: 'Fuga de gas'),
        AlertSubtypeOption(id: 'FIRE', label: 'Incendio'),
        AlertSubtypeOption(id: 'VIOLENCE', label: 'Violencia'),
        AlertSubtypeOption(id: 'FLOOD', label: 'Inundacion'),
        AlertSubtypeOption(id: 'ELECTRICAL', label: 'Electrica'),
        AlertSubtypeOption(id: 'STRUCTURAL', label: 'Locativa'),
        AlertSubtypeOption(id: 'DEPENDENT_SUPPORT', label: 'Dependiente'),
        AlertSubtypeOption(id: otherSubtypeId, label: 'Otro', requiresDetail: true),
      ],
    ),
    police: AlertCategoryDetailConfig(
      alertType: police,
      fallbackTitle: 'Eventualidad policial',
      subtypes: [
        AlertSubtypeOption(id: 'THEFTS', label: 'Hurtos'),
        AlertSubtypeOption(id: 'EXTORTION_KIDNAPPING', label: 'Extorsión y secuestro'),
        AlertSubtypeOption(id: 'INJURIES_THREATS', label: 'Lesiones y amenazas'),
        AlertSubtypeOption(id: 'PUBLIC_CONSUMPTION', label: 'Consumo en espacio público'),
        AlertSubtypeOption(id: 'FIGHTS', label: 'Riñas y confrontaciones'),
        AlertSubtypeOption(id: 'VANDALISM', label: 'Vandalismo'),
        AlertSubtypeOption(id: 'SUSPICIOUS_PRESENCE', label: 'Presencia de sospechosos'),
        AlertSubtypeOption(id: 'MINOR_AT_RISK', label: 'Menor en riesgo'),
        AlertSubtypeOption(id: 'MISSING_PERSON', label: 'Persona desaparecida'),
        AlertSubtypeOption(id: otherSubtypeId, label: 'Otro', requiresDetail: true),
      ],
    ),
    fire: AlertCategoryDetailConfig(
      alertType: fire,
      fallbackTitle: 'Bomberos',
      subtypes: [
        AlertSubtypeOption(id: 'FIRE', label: 'Incendio'),
        AlertSubtypeOption(id: 'GAS_LEAK_ODOR', label: 'Fuga de gas / olor'),
        AlertSubtypeOption(id: 'PEOPLE_RESCUE', label: 'Rescate de personas'),
        AlertSubtypeOption(id: 'HAZARDOUS_SUBSTANCES', label: 'Sustancias peligrosas'),
        AlertSubtypeOption(id: 'SHORT_CIRCUIT', label: 'Cortocircuito'),
        AlertSubtypeOption(id: 'ANIMAL_RESCUE', label: 'Rescate animal'),
        AlertSubtypeOption(id: 'FLOOD', label: 'Inundacion'),
        AlertSubtypeOption(id: 'DANGEROUS_FAUNA', label: 'Fauna peligrosa'),
        AlertSubtypeOption(id: 'LANDSLIDE', label: 'Derrumbe'),
        AlertSubtypeOption(id: 'TREE_OR_STRUCTURE_FALL', label: 'Arbol o estructura caida'),
        AlertSubtypeOption(id: otherSubtypeId, label: 'Otro', requiresDetail: true),
      ],
    ),
    securityBreach: AlertCategoryDetailConfig(
      alertType: securityBreach,
      fallbackTitle: 'Brecha de seguridad',
      subtypes: [
        AlertSubtypeOption(id: 'UNAUTHORIZED_ACCESS', label: 'Acceso no autorizado / intrusión'),
        AlertSubtypeOption(id: 'PERIMETER_BREACH', label: 'Brecha en perímetro o cerramiento'),
        AlertSubtypeOption(id: 'ALARM_OR_SURVEILLANCE', label: 'Falla de alarma o videovigilancia'),
        AlertSubtypeOption(id: 'SENSITIVE_ASSET', label: 'Activo o información sensible expuesta'),
        AlertSubtypeOption(id: 'CYBER_OR_SYSTEMS', label: 'Incidente en sistemas o ciberseguridad'),
        AlertSubtypeOption(id: otherSubtypeId, label: 'Otro', requiresDetail: true),
      ],
    ),
    roadEmergency: AlertCategoryDetailConfig(
      alertType: roadEmergency,
      fallbackTitle: 'Transito',
      subtypes: [
        AlertSubtypeOption(id: 'ACCIDENT', label: 'Accidente'),
        AlertSubtypeOption(id: 'BLOCKAGE', label: 'Bloqueo'),
        AlertSubtypeOption(id: 'POOR_SIGNALING', label: 'Mala senalizacion'),
        AlertSubtypeOption(id: 'RUN_OVER', label: 'Atropello'),
        AlertSubtypeOption(id: 'MEDICAL_ASSISTANCE', label: 'Asistencia medica'),
        AlertSubtypeOption(id: 'DOCUMENTS_OR_TOOLS', label: 'Documentos o herramientas'),
        AlertSubtypeOption(id: otherSubtypeId, label: 'Otro', requiresDetail: true),
      ],
    ),
    environmental: AlertCategoryDetailConfig(
      alertType: environmental,
      fallbackTitle: 'Eventualidad ambiental',
      subtypes: [
        AlertSubtypeOption(id: 'ILLEGAL_GARBAGE_DUMP', label: 'Acopio ilegal de basura'),
        AlertSubtypeOption(id: 'WATER_SOURCE_POLLUTION', label: 'Contaminación de fuentes hídricas'),
        AlertSubtypeOption(id: 'HAZARDOUS_SPILL', label: 'Derrame de sustancias peligrosas'),
        AlertSubtypeOption(id: 'WILDLIFE_RISK', label: 'Riesgos con fauna'),
        AlertSubtypeOption(id: 'OFFENSIVE_ODORS', label: 'Olores ofensivos'),
        AlertSubtypeOption(id: 'FIRES_AIR_QUALITY', label: 'Incendios y calidad del aire'),
        AlertSubtypeOption(id: 'NOISE_POLLUTION', label: 'Ruido'),
        AlertSubtypeOption(id: 'NATURAL_DISASTERS', label: 'Desastres naturales'),
        AlertSubtypeOption(id: 'FLORA_RISK', label: 'Riesgo con flora'),
        AlertSubtypeOption(id: otherSubtypeId, label: 'Otro', requiresDetail: true),
      ],
    ),
    accompaniment: AlertCategoryDetailConfig(
      alertType: accompaniment,
      fallbackTitle: 'Acompanamiento',
      subtypes: [
        AlertSubtypeOption(id: 'HARASSMENT', label: 'Acoso'),
        AlertSubtypeOption(id: 'BULLYING', label: 'Bullying'),
        AlertSubtypeOption(id: 'INSECURITY', label: 'Inseguridad'),
        AlertSubtypeOption(id: 'MISSING', label: 'Extraviados'),
        AlertSubtypeOption(id: 'MINOR_CARE', label: 'Cuidado de menores'),
        AlertSubtypeOption(id: 'DISABILITY_SUPPORT', label: 'Personas con discapacidad'),
        AlertSubtypeOption(id: otherSubtypeId, label: 'Otro', requiresDetail: true),
      ],
    ),
    harassment: AlertCategoryDetailConfig(
      alertType: harassment,
      fallbackTitle: 'Acoso',
      subtypes: [
        AlertSubtypeOption(id: 'HARASSMENT', label: 'Acoso'),
        AlertSubtypeOption(id: otherSubtypeId, label: 'Otro', requiresDetail: true),
      ],
    ),
  };

  static AlertCategoryDetailConfig? getCategory(String alertType) => categories[alertType];

  static List<AlertSubtypeOption> getSubtypes(String alertType) =>
      categories[alertType]?.subtypes ?? const [];

  static bool supportsDetailStep(String alertType) => categories.containsKey(alertType);

  static bool subtypeRequiresDetail(String alertType, String subtypeId) {
    for (final option in getSubtypes(alertType)) {
      if (option.id == subtypeId) return option.requiresDetail;
    }
    return false;
  }

  static IconData getCategoryIcon(String alertType) {
    switch (alertType) {
      case health:
        return Icons.local_hospital;
      case homeHelp:
        return Icons.home;
      case police:
        return Icons.local_police;
      case fire:
        return Icons.local_fire_department;
      case securityBreach:
        return Icons.security_update_warning_rounded;
      case accompaniment:
        return Icons.people;
      case environmental:
        return Icons.nature_people;
      case roadEmergency:
        return Icons.directions_car;
      case harassment:
        return Icons.shield_rounded;
      default:
        return Icons.warning;
    }
  }
}

class AlertCategoryDetailConfig {
  final String alertType;
  final String fallbackTitle;
  final List<AlertSubtypeOption> subtypes;

  const AlertCategoryDetailConfig({
    required this.alertType,
    required this.fallbackTitle,
    required this.subtypes,
  });
}

class AlertSubtypeOption {
  final String id;
  final String label;
  final bool requiresDetail;

  const AlertSubtypeOption({
    required this.id,
    required this.label,
    this.requiresDetail = false,
  });
}
