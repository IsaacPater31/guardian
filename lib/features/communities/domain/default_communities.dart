import 'package:flutter/material.dart';

/// Plantilla para una comunidad creada automáticamente al primer acceso.
class DefaultCommunityTemplate {
  const DefaultCommunityTemplate({
    required this.slug,
    required this.name,
    this.description,
    this.iconCodePoint,
    this.iconColor,
  });

  /// Clave estable en Firestore (`default_slug`); no depende del nombre visible.
  final String slug;
  final String name;
  final String? description;
  final int? iconCodePoint;
  final String? iconColor;
}

/// Comunidades por defecto que cada usuario recibe si aún no pertenece a ninguna.
///
/// Edita [templates] para agregar, quitar o renombrar comunidades iniciales.
abstract final class DefaultCommunities {
  static final List<DefaultCommunityTemplate> templates = [
    DefaultCommunityTemplate(
      slug: 'hogar',
      name: 'Hogar',
      iconCodePoint: Icons.home.codePoint,
      iconColor: '#795548',
    ),
  ];
}
