/// Normaliza valores históricos de Firestore `alertType` a la nomenclatura corta
/// en español (una palabra) usada por la app y los nuevos documentos.
///
/// Documentación de alias: clientes antiguos pueden seguir escribiendo claves
/// `HOME_HELP`, `POLICE`, etc.; al leer se unifican a `casa`, `policial`, …
class AlertTypeNormalize {
  AlertTypeNormalize._();

  /// `alertType` antiguo → canónico (nuevo).
  static const Map<String, String> legacyToCanonical = {
    'HOME_HELP': 'casa',
    'SECURITY_BREACH': 'seguridad',
    'ROAD_EMERGENCY': 'vial',
    'HARASSMENT': 'acoso',
    'ENVIRONMENTAL': 'ambiental',
    'POLICE': 'policial',
    'VIAL EMERGENCY': 'vial',
  };

  /// Inverso para migrar claves de SharedPreferences (`swipe_alert_communities_*`).
  static const Map<String, String> canonicalToLegacyPrefKey = {
    'casa': 'HOME_HELP',
    'seguridad': 'SECURITY_BREACH',
    'vial': 'ROAD_EMERGENCY',
    'acoso': 'HARASSMENT',
    'ambiental': 'ENVIRONMENTAL',
    'policial': 'POLICE',
  };

  static String apply(String rawAlertType, String flowType) {
    var t = rawAlertType.trim();
    if (flowType == 'quick' && t == 'HEALTH') {
      return 'URGENCY';
    }
    return legacyToCanonical[t] ?? t;
  }
}
