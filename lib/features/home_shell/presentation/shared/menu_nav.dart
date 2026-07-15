import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

class MenuNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MenuNav({super.key, required this.currentIndex, required this.onTap});

  static const Color _selected = Color(0xFF1F2937);
  static const Color _unselected = Color(0xFF757575);

  /// Ancho mínimo de un tab (objetivo táctil razonable).
  static const double _minSlotWidth = 52.0;
  static const double _hPad = 3.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final shortest = mq.size.shortestSide;
    final textScaler = MediaQuery.textScalerOf(context);
    final textScale = textScaler.scale(1.0);
    final items = <_NavItemSpec>[
      _NavItemSpec(Icons.home, l10n.home),
      _NavItemSpec(Icons.people, l10n.communities),
      _NavItemSpec(Icons.bar_chart, l10n.statistics),
      _NavItemSpec(Icons.map, l10n.map),
      _NavItemSpec(Icons.person, l10n.profile),
    ];

    final compact = shortest < 360;
    final iconSel = compact ? 20.0 : (w < 420 ? 22.0 : 24.0);
    final iconUnsel = compact ? 18.0 : (w < 420 ? 20.0 : 22.0);
    final labelBase = compact ? 10.0 : (w < 400 ? 10.5 : 11.0);
    final navHeight = (60.0 + (textScale - 1) * 8).clamp(58.0, 72.0);

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      clipBehavior: Clip.hardEdge,
      child: SafeArea(
        top: false,
        child: MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.12,
          child: SizedBox(
            height: navHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final labels = items.map((item) => item.label).toList();
                final clampedScaler = MediaQuery.textScalerOf(context);

                // Ancho deseado por tab según su label: los textos largos
                // (Comunidades, Estadísticas) reciben más espacio que Mapa/Perfil.
                final desired = labels
                    .map(
                      (label) => math.max(
                        _minSlotWidth,
                        _singleLineWidth(
                              context: context,
                              label: label,
                              fontSize: labelBase,
                              textScaler: clampedScaler,
                            ) +
                            _hPad * 2,
                      ),
                    )
                    .toList();
                final totalDesired = desired.fold(0.0, (a, b) => a + b);

                var labelFontSize = labelBase;
                List<double> slotWidths;
                if (totalDesired <= constraints.maxWidth) {
                  // Todos los labels caben a tamaño completo: repartir el
                  // espacio sobrante en partes iguales.
                  final extra =
                      (constraints.maxWidth - totalDesired) / items.length;
                  slotWidths = desired.map((d) => d + extra).toList();
                } else {
                  // Pantalla muy estrecha o textScale extremo: slots iguales
                  // y fuente reducida proporcionalmente.
                  final slotW = constraints.maxWidth / items.length;
                  slotWidths = List.filled(items.length, slotW);
                  labelFontSize = _resolveLabelFontSize(
                    context: context,
                    labels: labels,
                    maxWidth: math.max(24.0, slotW - _hPad * 2),
                    baseSize: labelBase,
                    textScaler: clampedScaler,
                  );
                }

                final iconSlotH = math.min(iconSel, navHeight * 0.4);
                const gap = 2.0;
                final labelAreaH = math.max(
                  12.0,
                  navHeight - iconSlotH - gap - 4,
                );

                return Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        flex: (slotWidths[i] * 100).round(),
                        child: _NavTile(
                          spec: items[i],
                          label: labels[i],
                          selected: currentIndex == i,
                          onTap: () => onTap(i),
                          iconSize: currentIndex == i ? iconSel : iconUnsel,
                          iconSlotH: iconSlotH,
                          labelFontSize: labelFontSize,
                          labelAreaH: labelAreaH,
                          hPad: _hPad,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Proportional scale so the widest label (w600) fits inside [maxWidth].
  static double _resolveLabelFontSize({
    required BuildContext context,
    required List<String> labels,
    required double maxWidth,
    required double baseSize,
    required TextScaler textScaler,
  }) {
    final widest = labels
        .map(
          (label) => _singleLineWidth(
            context: context,
            label: label,
            fontSize: baseSize,
            textScaler: textScaler,
          ),
        )
        .fold(0.0, math.max);

    if (widest <= 0 || widest <= maxWidth) return baseSize;

    const safety = 0.94;
    return baseSize * (maxWidth / widest) * safety;
  }

  static double _singleLineWidth({
    required BuildContext context,
    required String label,
    required double fontSize,
    required TextScaler textScaler,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);
    return painter.width;
  }
}

class _NavItemSpec {
  const _NavItemSpec(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.spec,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.iconSize,
    required this.iconSlotH,
    required this.labelFontSize,
    required this.labelAreaH,
    required this.hPad,
  });

  final _NavItemSpec spec;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double iconSize;
  final double iconSlotH;
  final double labelFontSize;
  final double labelAreaH;
  final double hPad;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MenuNav._selected : MenuNav._unselected;
    final iconS = math.min(iconSize, iconSlotH);
    final style = TextStyle(
      fontSize: labelFontSize,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      color: color,
      height: 1.0,
    );

    return ClipRect(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: iconSlotH,
                  width: double.infinity,
                  child: Center(
                    child: Icon(spec.icon, size: iconS, color: color),
                  ),
                ),
                const SizedBox(height: 2),
                ClipRect(
                  child: SizedBox(
                    width: double.infinity,
                    height: labelAreaH,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: style,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
