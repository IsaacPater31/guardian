import 'package:flutter/material.dart';

/// Catálogo curado de iconos para comunidades.
///
/// Mantener en sync manual con `webapp/src/config/communityIconCatalog.js`.
class CommunityIconCatalog {
  CommunityIconCatalog._();

  static const int defaultIconCodePoint = 58502;
  static const String defaultIconColor = '#5B6ABF';

  static const List<CommunityIconCatalogEntry> entries = [
    CommunityIconCatalogEntry(codePoint: 58502, label: 'Grupo', colorHex: '#5B6ABF'),
    CommunityIconCatalogEntry(codePoint: 58094, label: 'Comunidad', colorHex: '#7C4DFF'),
    CommunityIconCatalogEntry(codePoint: 57943, label: 'Familia', colorHex: '#E91E63'),
    CommunityIconCatalogEntry(codePoint: 985180, label: 'Diversidad', colorHex: '#FF5722'),
    CommunityIconCatalogEntry(codePoint: 984766, label: 'Alianza', colorHex: '#009688'),
    CommunityIconCatalogEntry(codePoint: 58136, label: 'Hogar', colorHex: '#795548'),
    CommunityIconCatalogEntry(codePoint: 58280, label: 'Ciudad', colorHex: '#607D8B'),
    CommunityIconCatalogEntry(codePoint: 57481, label: 'Edificio', colorHex: '#455A64'),
    CommunityIconCatalogEntry(codePoint: 58412, label: 'Refugio', colorHex: '#8D6E63'),
    CommunityIconCatalogEntry(codePoint: 58312, label: 'Zona', colorHex: '#4CAF50'),
    CommunityIconCatalogEntry(codePoint: 58713, label: 'Escuela', colorHex: '#1976D2'),
    CommunityIconCatalogEntry(codePoint: 59122, label: 'Trabajo', colorHex: '#F57C00'),
    CommunityIconCatalogEntry(codePoint: 57627, label: 'Empresa', colorHex: '#37474F'),
    CommunityIconCatalogEntry(codePoint: 58714, label: 'Ciencia', colorHex: '#00BCD4'),
    CommunityIconCatalogEntry(codePoint: 58333, label: 'Estudio', colorHex: '#3F51B5'),
    CommunityIconCatalogEntry(codePoint: 58866, label: 'Fútbol', colorHex: '#388E3C'),
    CommunityIconCatalogEntry(codePoint: 57997, label: 'Gimnasio', colorHex: '#D32F2F'),
    CommunityIconCatalogEntry(codePoint: 57820, label: 'Correr', colorHex: '#FF6F00'),
    CommunityIconCatalogEntry(codePoint: 58854, label: 'Basket', colorHex: '#E65100'),
    CommunityIconCatalogEntry(codePoint: 58588, label: 'Natación', colorHex: '#0288D1'),
    CommunityIconCatalogEntry(codePoint: 58262, label: 'Salud', colorHex: '#C62828'),
    CommunityIconCatalogEntry(codePoint: 57947, label: 'Bienestar', colorHex: '#AD1457'),
    CommunityIconCatalogEntry(codePoint: 58116, label: 'Cuidado', colorHex: '#00897B'),
    CommunityIconCatalogEntry(codePoint: 59078, label: 'Voluntariado', colorHex: '#F06292'),
    CommunityIconCatalogEntry(codePoint: 984269, label: 'Iglesia', colorHex: '#6D4C41'),
    CommunityIconCatalogEntry(codePoint: 57535, label: 'Cultura', colorHex: '#1565C0'),
    CommunityIconCatalogEntry(codePoint: 58389, label: 'Música', colorHex: '#AB47BC'),
    CommunityIconCatalogEntry(codePoint: 58964, label: 'Teatro', colorHex: '#FF7043'),
    CommunityIconCatalogEntry(codePoint: 58774, label: 'Seguridad', colorHex: '#1F2937'),
    CommunityIconCatalogEntry(codePoint: 58729, label: 'Vigilancia', colorHex: '#263238'),
    CommunityIconCatalogEntry(codePoint: 984314, label: 'Emergencia', colorHex: '#B71C1C'),
    CommunityIconCatalogEntry(codePoint: 58448, label: 'Alertas', colorHex: '#FF8F00'),
  ];

  static final Map<int, CommunityIconCatalogEntry> _byCodePoint = {
    for (final entry in entries) entry.codePoint: entry,
  };

  static IconData iconFromCodePoint(int codePoint) {
    return IconData(
      codePoint,
      fontFamily: 'MaterialIcons',
    );
  }

  static Color colorFromHex(String hex) {
    var normalized = hex.replaceFirst('#', '');
    if (normalized.length == 6) normalized = 'FF$normalized';
    return Color(int.parse(normalized, radix: 16));
  }

  static CommunityIconCatalogEntry? entryForCodePoint(int? codePoint) {
    if (codePoint == null) return null;
    return _byCodePoint[codePoint];
  }
}

class CommunityIconCatalogEntry {
  final int codePoint;
  final String label;
  final String colorHex;

  const CommunityIconCatalogEntry({
    required this.codePoint,
    required this.label,
    required this.colorHex,
  });

  IconData get icon => CommunityIconCatalog.iconFromCodePoint(codePoint);

  Color get color => CommunityIconCatalog.colorFromHex(colorHex);
}
