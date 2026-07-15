/// Custom report type configured on an entity (`report_alert_types` objects).
class EntityReportType {
  final String id;
  final String name;
  final int iconCodePoint;
  final String color;

  const EntityReportType({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.color,
  });

  static const int defaultIconCodePoint = 58502;
  static const String defaultColor = '#5B6ABF';

  factory EntityReportType.fromMap(Map<String, dynamic> map) {
    final name = (map['name'] as String?)?.trim() ?? '';
    final id = (map['id'] as String?)?.trim();
    final icon = map['iconCodePoint'] ?? map['icon_code_point'];
    final colorRaw = (map['color'] ?? map['iconColor'] ?? map['icon_color'])
        ?.toString()
        .trim();
    final iconCode = icon is int
        ? icon
        : int.tryParse(icon?.toString() ?? '') ?? defaultIconCodePoint;
    final color = (colorRaw != null &&
            RegExp(r'^#([0-9a-fA-F]{6})$').hasMatch(colorRaw))
        ? colorRaw.toUpperCase()
        : defaultColor;
    return EntityReportType(
      id: (id != null && id.isNotEmpty)
          ? id
          : 'ert_${name.hashCode.abs()}',
      name: name,
      iconCodePoint: iconCode > 0 ? iconCode : defaultIconCodePoint,
      color: color,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconCodePoint': iconCodePoint,
        'color': color,
      };

  /// Parses Firestore `report_alert_types`. Legacy string keys are ignored.
  static List<EntityReportType> parseList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <EntityReportType>[];
    for (final item in raw) {
      if (item is Map) {
        final typed = EntityReportType.fromMap(Map<String, dynamic>.from(item));
        if (typed.name.isNotEmpty) out.add(typed);
      }
    }
    return out;
  }
}
