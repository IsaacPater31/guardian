import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_constants.dart';

/// Definitions for the four built-in entity communities seeded on first run.
///
/// Centralising this data here means that adding, renaming, or recolouring
/// an entity requires a single change in one place rather than editing
/// business-logic code inside [CommunityService].
abstract final class EntityDefinitions {
  /// The canonical list of entity communities that must always exist.
  static const List<Map<String, dynamic>> defaultEntities = [
    {
      CommunityFields.name: 'AMBIENTAL',
      CommunityFields.description: 'Entidad Ambiental',
      CommunityFields.iconCodePoint: 0xe217,
      CommunityFields.iconColor: '#4CAF50',
    },
    {
      CommunityFields.name: 'POLICIA',
      CommunityFields.description: 'Policía Nacional',
      CommunityFields.iconCodePoint: 0xe3a2,
      CommunityFields.iconColor: '#1565C0',
    },
    {
      CommunityFields.name: 'BOMBEROS',
      CommunityFields.description: 'Cuerpo de Bomberos',
      CommunityFields.iconCodePoint: 0xe392,
      CommunityFields.iconColor: '#E53935',
    },
    {
      CommunityFields.name: 'TRANSITO',
      CommunityFields.description: 'Tránsito y Transporte',
      CommunityFields.iconCodePoint: 0xe674,
      CommunityFields.iconColor: '#FF9800',
    },
  ];

  /// Firestore document template for a new entity community.
  static Map<String, dynamic> toFirestore(Map<String, dynamic> entity) => {
        CommunityFields.name: entity[CommunityFields.name],
        CommunityFields.description: entity[CommunityFields.description],
        CommunityFields.isEntity: true,
        CommunityFields.createdBy: null,
        CommunityFields.allowForwardToEntities: false,
        CommunityFields.createdAt: Timestamp.now(),
        CommunityFields.iconCodePoint: entity[CommunityFields.iconCodePoint],
        CommunityFields.iconColor: entity[CommunityFields.iconColor],
      };
}
