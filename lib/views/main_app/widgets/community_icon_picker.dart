import 'package:flutter/material.dart';

/// Catálogo curado de iconos disponibles para comunidades.
/// Usa Material Icons codePoints — no requiere Storage ni imágenes.
class CommunityIconPicker {
  CommunityIconPicker._();

  /// Iconos disponibles para comunidades personales, agrupados por categoría.
  static const List<CommunityIconOption> availableIcons = [
    // Personas & Grupos
    CommunityIconOption(Icons.people, 'Grupo', '#5B6ABF'),
    CommunityIconOption(Icons.groups, 'Comunidad', '#7C4DFF'),
    CommunityIconOption(Icons.family_restroom, 'Familia', '#E91E63'),
    CommunityIconOption(Icons.diversity_3, 'Diversidad', '#FF5722'),
    CommunityIconOption(Icons.handshake, 'Alianza', '#009688'),

    // Ubicación & Barrio
    CommunityIconOption(Icons.home, 'Hogar', '#795548'),
    CommunityIconOption(Icons.location_city, 'Ciudad', '#607D8B'),
    CommunityIconOption(Icons.apartment, 'Edificio', '#455A64'),
    CommunityIconOption(Icons.night_shelter, 'Refugio', '#8D6E63'),
    CommunityIconOption(Icons.map, 'Zona', '#4CAF50'),

    // Educación & Trabajo
    CommunityIconOption(Icons.school, 'Escuela', '#1976D2'),
    CommunityIconOption(Icons.work, 'Trabajo', '#F57C00'),
    CommunityIconOption(Icons.business, 'Empresa', '#37474F'),
    CommunityIconOption(Icons.science, 'Ciencia', '#00BCD4'),
    CommunityIconOption(Icons.menu_book, 'Estudio', '#3F51B5'),

    // Deporte & Actividades
    CommunityIconOption(Icons.sports_soccer, 'Fútbol', '#388E3C'),
    CommunityIconOption(Icons.fitness_center, 'Gimnasio', '#D32F2F'),
    CommunityIconOption(Icons.directions_run, 'Correr', '#FF6F00'),
    CommunityIconOption(Icons.sports_basketball, 'Basket', '#E65100'),
    CommunityIconOption(Icons.pool, 'Natación', '#0288D1'),

    // Salud & Bienestar
    CommunityIconOption(Icons.local_hospital, 'Salud', '#C62828'),
    CommunityIconOption(Icons.favorite, 'Bienestar', '#AD1457'),
    CommunityIconOption(Icons.healing, 'Cuidado', '#00897B'),
    CommunityIconOption(Icons.volunteer_activism, 'Voluntariado', '#F06292'),

    // Religión & Cultura
    CommunityIconOption(Icons.church, 'Iglesia', '#6D4C41'),
    CommunityIconOption(Icons.auto_stories, 'Cultura', '#1565C0'),
    CommunityIconOption(Icons.music_note, 'Música', '#AB47BC'),
    CommunityIconOption(Icons.theater_comedy, 'Teatro', '#FF7043'),

    // Seguridad
    CommunityIconOption(Icons.shield, 'Seguridad', '#1F2937'),
    CommunityIconOption(Icons.security, 'Vigilancia', '#263238'),
    CommunityIconOption(Icons.emergency, 'Emergencia', '#B71C1C'),
    CommunityIconOption(Icons.notifications_active, 'Alertas', '#FF8F00'),
  ];

  /// Icono por defecto para comunidades sin icono (fallback)
  static const int defaultIconCodePoint = 0xe7ef; // Icons.people
  static const String defaultIconColor = '#5B6ABF';

  /// Cache para mapeo de codePoint -> IconData, inicializado una sola vez
  static final Map<int, IconData> _codePointToIcon = {
    for (var option in availableIcons) option.codePoint: option.icon,
  };

  /// Obtiene IconData desde codePoint con cache
  static IconData iconFromCodePoint(int codePoint) {
    return _codePointToIcon[codePoint] ?? Icons.people;
  }

  /// Convierte hex string a Color
  static Color colorFromHex(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

/// Opción individual de icono
class CommunityIconOption {
  final IconData icon;
  final String label;
  final String colorHex;

  const CommunityIconOption(this.icon, this.label, this.colorHex);

  int get codePoint => icon.codePoint;
  Color get color => CommunityIconPicker.colorFromHex(colorHex);
}

/// Widget selector de icono para comunidades.
/// Muestra una grilla de iconos curados con diseño Apple-inspired.
class CommunityIconPickerGrid extends StatelessWidget {
  final int? selectedCodePoint;
  final String? selectedColor;
  final ValueChanged<CommunityIconOption> onIconSelected;

  const CommunityIconPickerGrid({
    super.key,
    this.selectedCodePoint,
    this.selectedColor,
    required this.onIconSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Icono de la comunidad',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: CommunityIconPicker.availableIcons.length,
            itemBuilder: (context, index) {
              final option = CommunityIconPicker.availableIcons[index];
              final isSelected = option.codePoint == selectedCodePoint;

              return GestureDetector(
                onTap: () => onIconSelected(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? option.color.withValues(alpha: 0.15)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? option.color
                          : Colors.grey[200]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Tooltip(
                    message: option.label,
                    child: Icon(
                      option.icon,
                      size: 22,
                      color: isSelected ? option.color : Colors.grey[500],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Widget para mostrar el icono de una comunidad.
/// Usa el codePoint y color almacenados o fallback al default.
class CommunityIconDisplay extends StatelessWidget {
  final int? iconCodePoint;
  final String? iconColor;
  final bool isEntity;
  final double size;

  const CommunityIconDisplay({
    super.key,
    this.iconCodePoint,
    this.iconColor,
    this.isEntity = false,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final hasCustomIcon = iconCodePoint != null;
    final color = iconColor != null
        ? CommunityIconPicker.colorFromHex(iconColor!)
        : isEntity
            ? const Color(0xFF1565C0)
            : CommunityIconPicker.colorFromHex(CommunityIconPicker.defaultIconColor);
    final icon = hasCustomIcon
        ? CommunityIconPicker.iconFromCodePoint(iconCodePoint!)
        : isEntity
            ? Icons.shield
            : CommunityIconPicker.iconFromCodePoint(CommunityIconPicker.defaultIconCodePoint);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: size * 0.5,
      ),
    );
  }
}
