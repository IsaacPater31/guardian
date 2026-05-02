import 'package:flutter/widgets.dart';
import 'package:guardian/core/alert_detail_catalog.dart';
import 'package:guardian/models/emergency_types.dart';

/// Resolves catalog subtype + optional free-text for UI (ES / EN).
class AlertSubtypeDisplay {
  AlertSubtypeDisplay._();

  /// English labels for catalog subtype IDs (subset; unknown IDs are title-cased).
  static const Map<String, Map<String, String>> _en = {
    AlertDetailCatalog.police: {
      'ROBBERY': 'Theft / robbery',
      'SUSPICIOUS_ACTIVITY': 'Suspicious activity',
      'GENDER_VIOLENCE': 'Gender-based violence',
      'PUBLIC_ORDER': 'Public order',
      'EXTORTION': 'Extortion',
      'SICARIATO': 'Contract killing',
      'FLETEO': 'Express kidnapping',
      'KIDNAPPING': 'Kidnapping',
      'ANIMAL_ABUSE': 'Animal abuse',
      'PREVENTIVE_PATROL': 'Preventive patrol',
      'MISSING_PERSONS': 'Missing persons',
      'NOISE': 'Noise',
      AlertDetailCatalog.otherSubtypeId: 'Other',
    },
    AlertDetailCatalog.fire: {
      'FIRE': 'Fire',
      'GAS_LEAK_ODOR': 'Gas leak / odor',
      'PEOPLE_RESCUE': 'People rescue',
      'HAZARDOUS_SUBSTANCES': 'Hazardous substances',
      'SHORT_CIRCUIT': 'Short circuit',
      'ANIMAL_RESCUE': 'Animal rescue',
      'FLOOD': 'Flood',
      'DANGEROUS_FAUNA': 'Dangerous fauna',
      'LANDSLIDE': 'Landslide',
      'TREE_OR_STRUCTURE_FALL': 'Fallen tree or structure',
      AlertDetailCatalog.otherSubtypeId: 'Other',
    },
    AlertDetailCatalog.securityBreach: {
      'UNAUTHORIZED_ACCESS': 'Unauthorized access / intrusion',
      'PERIMETER_BREACH': 'Perimeter or fencing breach',
      'ALARM_OR_SURVEILLANCE': 'Alarm or CCTV failure',
      'SENSITIVE_ASSET': 'Sensitive asset or data exposed',
      'CYBER_OR_SYSTEMS': 'Systems or cybersecurity incident',
      AlertDetailCatalog.otherSubtypeId: 'Other',
    },
    AlertDetailCatalog.health: {
      'FIRST_AID': 'First aid',
      'MEDICATIONS': 'Medications',
      'AMBULANCE': 'Ambulance',
      'MENTAL_HEALTH': 'Mental health',
      'NEED_DOCTOR': 'Need a doctor',
      AlertDetailCatalog.otherSubtypeId: 'Other',
    },
    AlertDetailCatalog.homeHelp: {
      'GAS_LEAK': 'Gas leak',
      'FIRE': 'Fire',
      'VIOLENCE': 'Violence',
      'FLOOD': 'Flood',
      'ELECTRICAL': 'Electrical',
      'STRUCTURAL': 'Structural',
      'DEPENDENT_SUPPORT': 'Dependent care',
      AlertDetailCatalog.otherSubtypeId: 'Other',
    },
    AlertDetailCatalog.roadEmergency: {
      'ACCIDENT': 'Accident',
      'BLOCKAGE': 'Blockage',
      'POOR_SIGNALING': 'Poor signage',
      'RUN_OVER': 'Run-over',
      'MEDICAL_ASSISTANCE': 'Medical assistance',
      'DOCUMENTS_OR_TOOLS': 'Documents or tools',
      AlertDetailCatalog.otherSubtypeId: 'Other',
    },
    AlertDetailCatalog.environmental: {
      'NOISE_POLLUTION': 'Noise pollution',
      'ILLEGAL_DUMPS': 'Illegal dumping',
      'TREE_LOGGING': 'Illegal logging',
      'WATER_POLLUTION': 'Water pollution',
      'INVASIVE_SPECIES': 'Invasive species',
      'HAZARDOUS_WASTE': 'Hazardous waste',
      'DANGEROUS_ANIMALS': 'Dangerous animals',
      'ANIMAL_IN_DANGER': 'Animal in danger',
      'AIR_POLLUTION': 'Air pollution',
      AlertDetailCatalog.otherSubtypeId: 'Other',
    },
    AlertDetailCatalog.accompaniment: {
      'HARASSMENT': 'Harassment',
      'BULLYING': 'Bullying',
      'INSECURITY': 'Insecurity',
      'MISSING': 'Missing',
      'MINOR_CARE': 'Child care',
      'DISABILITY_SUPPORT': 'Disability support',
      AlertDetailCatalog.otherSubtypeId: 'Other',
    },
    AlertDetailCatalog.harassment: {
      'HARASSMENT': 'Harassment',
      AlertDetailCatalog.otherSubtypeId: 'Other',
    },
  };

  static String _humanizeId(String id) {
    if (id.isEmpty) return id;
    return id
        .split('_')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Localized subtype line (empty if none).
  static String line(
    BuildContext context,
    String alertType,
    String? subtypeId,
    String? customDetail,
  ) {
    if (subtypeId == null || subtypeId.isEmpty) return '';
    if (subtypeId == AlertDetailCatalog.otherSubtypeId) {
      final t = customDetail?.trim() ?? '';
      return t;
    }
    final options = AlertDetailCatalog.getSubtypes(alertType);
    for (final o in options) {
      if (o.id == subtypeId) {
        final code = Localizations.localeOf(context).languageCode;
        if (code == 'es') return o.label;
        return _en[alertType]?[subtypeId] ?? _humanizeId(subtypeId);
      }
    }
    return _humanizeId(subtypeId);
  }

  static String? primaryWithSubtypeLine(
    BuildContext context,
    String alertType,
    String? subtypeId,
    String? customDetail,
  ) {
    final main = EmergencyTypes.getTranslatedType(alertType, context);
    final sub = line(context, alertType, subtypeId, customDetail);
    if (sub.isEmpty) return main;
    return '$main → $sub';
  }
}
