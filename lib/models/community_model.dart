import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityModel {
  final String? id;
  final String name;
  final String? description;
  final bool isEntity; // true para AMBIENTAL, POLICIA, BOMBEROS, TRANSITO
  final String? createdBy; // null para entidades, user_id para comunidades normales
  final bool allowForwardToEntities; // Solo creador puede cambiar
  final DateTime createdAt;

  CommunityModel({
    this.id,
    required this.name,
    this.description,
    required this.isEntity,
    this.createdBy,
    this.allowForwardToEntities = true,
    required this.createdAt,
  });

  factory CommunityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      isEntity: data['is_entity'] ?? false,
      createdBy: data['created_by'],
      allowForwardToEntities: data['allow_forward_to_entities'] ?? true,
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'is_entity': isEntity,
      'created_by': createdBy,
      'allow_forward_to_entities': allowForwardToEntities,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  CommunityModel copyWith({
    String? id,
    String? name,
    String? description,
    bool? isEntity,
    String? createdBy,
    bool? allowForwardToEntities,
    DateTime? createdAt,
  }) {
    return CommunityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isEntity: isEntity ?? this.isEntity,
      createdBy: createdBy ?? this.createdBy,
      allowForwardToEntities: allowForwardToEntities ?? this.allowForwardToEntities,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

