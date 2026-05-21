/// IDs de entidades oficiales en Firestore (`communities/{id}`).
///
/// Ya existen en el proyecto; la app **no las crea**. Al cambiar de entorno
/// o desplegar otra instancia, copia los IDs exactos desde el panel (sensibles
/// a mayúsculas) y edita solo esta lista.
abstract final class DefaultOfficialEntities {
  /// AMBIENTAL — Entidad Ambiental
  static const String ambiental = 'OunhMgaYqRkDtkGeVCOT';

  /// POLICIA — Policía Nacional
  static const String policia = 'oVfz8lfZRDRlHLr44MKf';

  /// TRANSITO — Tránsito y Transporte
  static const String transito = 'd9T4mhL0yQgi98HFUxRP';

  /// BOMBEROS — Cuerpo de Bomberos
  static const String bomberos = 'wpizDJLI79c2CKKr5Kw3';

  /// Comunidades a las que se une el usuario en el primer acceso (y si falta alguna).
  static const List<String> communityIds = [
    ambiental,
    policia,
    transito,
    bomberos,
  ];

  /// Etiqueta legible por ID (logs en consola).
  static String labelForId(String communityId) {
    if (communityId == ambiental) return 'AMBIENTAL';
    if (communityId == policia) return 'POLICIA';
    if (communityId == transito) return 'TRANSITO';
    if (communityId == bomberos) return 'BOMBEROS';
    return communityId;
  }

  /// Palabras clave de [EmergencyTypes.defaultCommunityKeyword] → ID.
  static const Map<String, String> keywordToCommunityId = {
    'AMBIENTAL': ambiental,
    'POLICIAL': policia,
    'POLICIA': policia,
    'TRANSITO': transito,
    'BOMBEROS': bomberos,
  };
}
