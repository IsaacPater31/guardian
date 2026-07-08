import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityModel {
  final String? id;
  final String name;
  final String? description;
  final bool isEntity; // Campo legacy en Firestore; oculto en la app.
  final String? createdBy;
  final DateTime createdAt;
  final int? iconCodePoint; // Material Icons codePoint (ej: Icons.people.codePoint)
  final String? iconColor; // Color en hex (ej: '#FF9500')

  CommunityModel({
    this.id,
    required this.name,
    this.description,
    required this.isEntity,
    this.createdBy,
    required this.createdAt,
    this.iconCodePoint,
    this.iconColor,
  });

  factory CommunityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      isEntity: data['is_entity'] ?? false,
      createdBy: data['created_by'],
      createdAt: (data['created_at'] as Timestamp).toDate(),
      iconCodePoint: data['icon_code_point'] as int?,
      iconColor: data['icon_color'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'is_entity': isEntity,
      'created_by': createdBy,
      'created_at': Timestamp.fromDate(createdAt),
      if (iconCodePoint != null) 'icon_code_point': iconCodePoint,
      if (iconColor != null) 'icon_color': iconColor,
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
    );
  }
}
