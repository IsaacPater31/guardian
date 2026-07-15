import 'package:flutter/material.dart';

import 'package:guardian/shared/catalog/community_icon_catalog.dart';

/// Catálogo curado de iconos disponibles para comunidades.
/// Usa Material Icons codePoints — no requiere Storage ni imágenes.
class CommunityIconPicker {
  CommunityIconPicker._();

  /// Iconos disponibles para comunidades personales.
  static List<CommunityIconCatalogEntry> get availableIcons =>
      CommunityIconCatalog.entries;

  /// Icono por defecto para comunidades sin icono (fallback)
  static const int defaultIconCodePoint = CommunityIconCatalog.defaultIconCodePoint;
  static const String defaultIconColor = CommunityIconCatalog.defaultIconColor;

  /// Obtiene IconData desde codePoint
  static IconData iconFromCodePoint(int codePoint) {
    return CommunityIconCatalog.iconFromCodePoint(codePoint);
  }

  /// Convierte hex string a Color
  static Color colorFromHex(String hex) {
    return CommunityIconCatalog.colorFromHex(hex);
  }
}

/// Opción individual de icono (alias de catálogo para compatibilidad).
typedef CommunityIconOption = CommunityIconCatalogEntry;

/// Widget selector de icono para comunidades.
/// Muestra una grilla de iconos curados con diseño Apple-inspired.
class CommunityIconPickerGrid extends StatelessWidget {
  final int? selectedCodePoint;
  final String? selectedColor;
  final ValueChanged<CommunityIconCatalogEntry> onIconSelected;

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
  final double size;

  const CommunityIconDisplay({
    super.key,
    this.iconCodePoint,
    this.iconColor,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final hasCustomIcon = iconCodePoint != null;
    final color = iconColor != null
        ? CommunityIconPicker.colorFromHex(iconColor!)
        : CommunityIconPicker.colorFromHex(CommunityIconPicker.defaultIconColor);
    final icon = hasCustomIcon
        ? CommunityIconPicker.iconFromCodePoint(iconCodePoint!)
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
