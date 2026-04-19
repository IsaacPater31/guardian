import 'package:flutter/material.dart';

/// Defines alert categories and subtype options for the swipe flow.
///
/// This catalog is intentionally local and editable so product/operations can
/// add, remove, or rename categories/subtypes without rewriting UI logic.
class AlertDetailCatalog {
  static const String health = 'HEALTH';
  static const String homeHelp = 'HOME_HELP';
  static const String police = 'POLICE';
  static const String fire = 'FIRE';
  static const String roadEmergency = 'ROAD_EMERGENCY';
  static const String environmental = 'ENVIRONMENTAL';
  static const String accompaniment = 'ACCOMPANIMENT';
  static const String otherSubtypeId = 'OTHER';

  static const List<String> supportedAlertTypes = [
    health,
    homeHelp,
    police,
    fire,
    roadEmergency,
    environmental,
    accompaniment,
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
      fallbackTitle: 'Policia',
      subtypes: [
        AlertSubtypeOption(id: 'ROBBERY', label: 'Robo'),
        AlertSubtypeOption(id: 'SUSPICIOUS_ACTIVITY', label: 'Actividad sospechosa'),
        AlertSubtypeOption(id: 'GENDER_VIOLENCE', label: 'Violencia de genero'),
        AlertSubtypeOption(id: 'PUBLIC_ORDER', label: 'Orden publico'),
        AlertSubtypeOption(id: 'EXTORTION', label: 'Extorsion'),
        AlertSubtypeOption(id: 'SICARIATO', label: 'Sicariato'),
        AlertSubtypeOption(id: 'FLETEO', label: 'Fleteo'),
        AlertSubtypeOption(id: 'KIDNAPPING', label: 'Secuestro'),
        AlertSubtypeOption(id: 'ANIMAL_ABUSE', label: 'Maltrato animal'),
        AlertSubtypeOption(id: 'PREVENTIVE_PATROL', label: 'Patrullaje preventivo'),
        AlertSubtypeOption(id: 'MISSING_PERSONS', label: 'Personas perdidas'),
        AlertSubtypeOption(id: 'NOISE', label: 'Ruido'),
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
      fallbackTitle: 'Ambiental',
      subtypes: [
        AlertSubtypeOption(id: 'NOISE_POLLUTION', label: 'Contaminacion auditiva'),
        AlertSubtypeOption(id: 'ILLEGAL_DUMPS', label: 'Basureros satelites'),
        AlertSubtypeOption(id: 'TREE_LOGGING', label: 'Tala de arboles'),
        AlertSubtypeOption(id: 'WATER_POLLUTION', label: 'Contaminacion hidrica'),
        AlertSubtypeOption(id: 'INVASIVE_SPECIES', label: 'Especies invasoras'),
        AlertSubtypeOption(id: 'HAZARDOUS_WASTE', label: 'Residuos peligrosos'),
        AlertSubtypeOption(id: 'DANGEROUS_ANIMALS', label: 'Animales peligrosos'),
        AlertSubtypeOption(id: 'ANIMAL_IN_DANGER', label: 'Animal en peligro'),
        AlertSubtypeOption(id: 'AIR_POLLUTION', label: 'Contaminacion del aire'),
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
  };

  static AlertCategoryDetailConfig? getCategory(String alertType) => categories[alertType];

  static List<AlertSubtypeOption> getSubtypes(String alertType) =>
      categories[alertType]?.subtypes ?? const [];

  static bool supportsDetailStep(String alertType) => categories.containsKey(alertType);

  static bool subtypeRequiresDetail(String alertType, String subtypeId) {
    final subtype = getSubtypes(alertType).cast<AlertSubtypeOption?>().firstWhere(
          (option) => option?.id == subtypeId,
          orElse: () => null,
        );
    return subtype?.requiresDetail ?? false;
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
      case accompaniment:
        return Icons.people;
      case environmental:
        return Icons.nature_people;
      case roadEmergency:
        return Icons.directions_car;
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
