import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/widgets/adaptive_fit_text.dart';

class MenuNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MenuNav({super.key, required this.currentIndex, required this.onTap});

  static const Color _selected = Color(0xFF1F2937);
  static const Color _unselected = Color(0xFF757575);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final items = <_NavItemSpec>[
      _NavItemSpec(Icons.home, l10n.home),
      _NavItemSpec(Icons.people, l10n.communities),
      _NavItemSpec(Icons.bar_chart, l10n.statistics),
      _NavItemSpec(Icons.map, l10n.map),
      _NavItemSpec(Icons.person, l10n.profile),
    ];

    final iconSel = w < 360 ? 22.0 : 24.0;
    final iconUnsel = w < 360 ? 20.0 : 22.0;
    final labelBase = w < 320 ? 9.5 : w < 360 ? 10.0 : w < 400 ? 10.5 : 11.5;

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: kBottomNavigationBarHeight,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return _NavTile(
                        spec: items[i],
                        selected: currentIndex == i,
                        onTap: () => onTap(i),
                        iconSize: currentIndex == i ? iconSel : iconUnsel,
                        labelFontSize: labelBase,
                        slotWidth: constraints.maxWidth,
                        maxHeight: constraints.maxHeight,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
    required this.selected,
    required this.onTap,
    required this.iconSize,
    required this.labelFontSize,
    required this.slotWidth,
    required this.maxHeight,
  });

  final _NavItemSpec spec;
  final bool selected;
  final VoidCallback onTap;
  final double iconSize;
  final double labelFontSize;
  final double slotWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MenuNav._selected : MenuNav._unselected;
    final labelMaxW = math.max(36.0, slotWidth - 4);
    final iconS = math.min(iconSize, maxHeight * 0.44);
    const gap = 2.0;
    final textH = math.max(14.0, maxHeight - iconS - gap - 4);

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: maxHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, size: iconS, color: color),
            const SizedBox(height: gap),
            SizedBox(
              width: labelMaxW,
              height: textH,
              child: AdaptiveFitText(
                text: spec.label,
                maxWidth: labelMaxW,
                maxHeight: textH,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: labelFontSize,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
