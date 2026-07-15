import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:guardian/features/entity_reports/domain/entity_report_type.dart';
import 'package:guardian/shared/config/app_constants.dart';

class CommunityModel {
  final String? id;
  final String name;
  final String? description;
  /// Entidad de reportes (creada solo desde el admin web). En la app se
  /// muestra en el apartado "Reportes" como "Reporte {nombre}".
  final bool isEntity;
  final String? createdBy;
  final DateTime createdAt;
  final int? iconCodePoint; // Material Icons codePoint (ej: Icons.people.codePoint)
  final String? iconColor; // Color en hex (ej: '#FF9500')
  final String? reportButtonColor; // Color botón reportar (ej: '#0D1B3E')
  /// Tipos de reporte personalizados (solo entidades).
  final List<EntityReportType> reportAlertTypes;

  CommunityModel({
    this.id,
    required this.name,
    this.description,
    required this.isEntity,
    this.createdBy,
    required this.createdAt,
    this.iconCodePoint,
    this.iconColor,
    this.reportButtonColor,
    this.reportAlertTypes = const [],
  });

  factory CommunityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdRaw = data[CommunityFields.createdAt];
    return CommunityModel(
      id: doc.id,
      name: data[CommunityFields.name] ?? '',
      description: data[CommunityFields.description],
      isEntity: data[CommunityFields.isEntity] ?? false,
      createdBy: data[CommunityFields.createdBy],
      createdAt: createdRaw is Timestamp
          ? createdRaw.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      iconCodePoint: data[CommunityFields.iconCodePoint] as int?,
      iconColor: data[CommunityFields.iconColor] as String?,
      reportButtonColor: data[CommunityFields.reportButtonColor] as String?,
      reportAlertTypes:
          EntityReportType.parseList(data[CommunityFields.reportAlertTypes]),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      CommunityFields.name: name,
      CommunityFields.description: description,
      CommunityFields.isEntity: isEntity,
      CommunityFields.createdBy: createdBy,
      CommunityFields.createdAt: Timestamp.fromDate(createdAt),
      if (iconCodePoint != null) CommunityFields.iconCodePoint: iconCodePoint,
      if (iconColor != null) CommunityFields.iconColor: iconColor,
      if (reportButtonColor != null)
        CommunityFields.reportButtonColor: reportButtonColor,
      if (isEntity && reportAlertTypes.isNotEmpty)
        CommunityFields.reportAlertTypes:
            reportAlertTypes.map((t) => t.toMap()).toList(),
    };
  }

  CommunityModel copyWith({
    String? id,
    String? name,
    String? description,
    bool? isEntity,
    String? createdBy,
    DateTime? createdAt,
    int? iconCodePoint,
    String? iconColor,
    String? reportButtonColor,
    List<EntityReportType>? reportAlertTypes,
  }) {
    return CommunityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isEntity: isEntity ?? this.isEntity,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconColor: iconColor ?? this.iconColor,
      reportButtonColor: reportButtonColor ?? this.reportButtonColor,
      reportAlertTypes: reportAlertTypes ?? this.reportAlertTypes,
    );
  }
}
