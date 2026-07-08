import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:guardian/core/app_constants.dart';
import 'package:guardian/core/community_icon_catalog.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/views/main_app/widgets/community_icon_picker.dart';

/// Franja de tarjetas de reporte a entidades (estilo Home anterior).
class EntityReportCardsStrip extends StatelessWidget {
  const EntityReportCardsStrip({
    super.key,
    required this.entities,
    required this.onReport,
  });

  final List<Map<String, dynamic>> entities;
  final void Function(Map<String, dynamic> entity) onReport;
  static const String _defaultReportButtonHex = '#0D1B3E';

  static double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

  static double _lerpDouble(double a, double b, double t) =>
      a + (b - a) * _clamp01(t);

  static double _fluidScale(
    double input, {
    required double inMin,
    required double inMax,
  }) {
    if (inMax <= inMin) return 0;
    return _clamp01((input - inMin) / (inMax - inMin));
  }

  static double _resolveCardHeight({
    required double slotWidth,
    required double shortestSide,
    required bool isTablet,
  }) {
    final shortestT = _fluidScale(shortestSide, inMin: 320, inMax: 900);
    final slotT = _fluidScale(slotWidth, inMin: 148, inMax: 420);
    final fromSlot = slotWidth * 0.72;
    final fromShortest = _lerpDouble(
      136.0,
      isTablet ? 188.0 : 164.0,
      shortestT,
    );
    final blended = fromSlot * 0.55 + fromShortest * 0.45;
    final slotBoost = slotT * 12.0;
    return (blended + slotBoost).clamp(134.0, isTablet ? 210.0 : 188.0);
  }

  static Color _accentFromEntity(Map<String, dynamic> entity) {
    final hex = entity[CommunityFields.reportButtonColor] as String?;
    if (hex != null && hex.isNotEmpty) {
      return CommunityIconPicker.colorFromHex(hex);
    }
    return CommunityIconPicker.colorFromHex(_defaultReportButtonHex);
  }

  @override
  Widget build(BuildContext context) {
    if (entities.isEmpty) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final shortest = mq.size.shortestSide;
    final isTablet = shortest >= 600;
    final isLandscape = mq.orientation == Orientation.landscape;
    final isTabletLandscape = isTablet && isLandscape;
    final widthT = _fluidScale(w, inMin: 320, inMax: 1280);
    final hx = _lerpDouble(8.0, 22.0, widthT).clamp(8.0, 22.0);
    final baseGap = _lerpDouble(10.0, 18.0, widthT).clamp(10.0, 18.0);
    final gap = isTabletLandscape ? baseGap + 2.0 : baseGap;
    final bottomExtra = mq.padding.bottom > 16
        ? 6.0
        : mq.padding.bottom > 0
            ? 8.0
            : 12.0;
    final count = entities.length;
    final useRow = count <= 2 && w >= 520;
    final maxRow = w >= 720
        ? math.min(
            w * (isTabletLandscape ? 0.94 : 0.92),
            isTablet ? (isTabletLandscape ? 1180.0 : 980.0) : 860.0,
          )
        : double.infinity;

    return Padding(
      padding: EdgeInsets.fromLTRB(hx, 6, hx, bottomExtra),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxRow),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rowW = constraints.maxWidth;
              final slotW = useRow
                  ? math.max(120.0, (rowW - gap * (count - 1)) / count)
                  : math.max(148.0, math.min(220.0, rowW * 0.46));
              final cardHeight = _resolveCardHeight(
                slotWidth: slotW,
                shortestSide: shortest,
                isTablet: isTablet,
              );

              if (useRow) {
                return SizedBox(
                  height: cardHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < entities.length; i++) ...[
                        if (i > 0) SizedBox(width: gap),
                        Expanded(
                          child: EntityReportCard(
                            entity: entities[i],
                            slotWidth: slotW,
                            cardHeight: cardHeight,
                            accent: _accentFromEntity(entities[i]),
                            onReport: () => onReport(entities[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return SizedBox(
                height: cardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: entities.length,
                  separatorBuilder: (_, __) => SizedBox(width: gap),
                  itemBuilder: (context, index) {
                    final entity = entities[index];
                    return SizedBox(
                      width: slotW,
                      child: EntityReportCard(
                        entity: entity,
                        slotWidth: slotW,
                        cardHeight: cardHeight,
                        accent: _accentFromEntity(entity),
                        onReport: () => onReport(entity),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class EntityReportCard extends StatelessWidget {
  const EntityReportCard({
    super.key,
    required this.entity,
    required this.slotWidth,
    required this.cardHeight,
    required this.accent,
    required this.onReport,
  });

  final Map<String, dynamic> entity;
  final double slotWidth;
  final double cardHeight;
  final Color accent;
  final VoidCallback onReport;

  static double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

  static double _lerpDouble(double a, double b, double t) =>
      a + (b - a) * _clamp01(t);

  static double _fluidScale(
    double input, {
    required double inMin,
    required double inMax,
  }) {
    if (inMax <= inMin) return 0;
    return _clamp01((input - inMin) / (inMax - inMin));
  }

  static Color _onColorFor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.37 ? const Color(0xFF111111) : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = (entity[CommunityFields.name] as String?) ?? '';
    final codePoint =
        entity[CommunityFields.iconCodePoint] as int? ??
            CommunityIconCatalog.defaultIconCodePoint;
    final icon = CommunityIconPicker.iconFromCodePoint(codePoint);
    final surfaceTint =
        Color.alphaBlend(accent.withValues(alpha: 0.05), Colors.white);
    final primaryText = const Color(0xFF111827);
    final secondaryText = const Color(0xFF4B5563);
    final buttonText = _onColorFor(accent);

    final titleWide = l10n.reportEntityTile(name);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : slotWidth;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : cardHeight;
        final slotT = _fluidScale(maxW, inMin: 148, inMax: 420);
        final heightT = _fluidScale(maxH, inMin: 96, inMax: 210);
        final t = math.min(slotT, heightT);
        final veryCompact = maxH < 124;

        final pad = _lerpDouble(6.0, 16.0, t).clamp(6.0, 16.0);
        final radius = _lerpDouble(10.0, 16.0, t).clamp(10.0, 16.0);
        final iconBox = _lerpDouble(22.0, 52.0, t)
            .clamp(math.max(18.0, maxH * 0.16), 52.0)
            .toDouble();
        final iconSize = iconBox * 0.56;
        final titleSize = _lerpDouble(10.0, 16.0, t).clamp(10.0, 16.0);
        final btnSize = _lerpDouble(10.0, 14.0, t).clamp(10.0, 14.0);
        final innerGap = _lerpDouble(4.0, 12.0, t).clamp(3.0, 12.0);
        final btnTopGap = _lerpDouble(4.0, 12.0, t).clamp(3.0, 12.0);
        final btnHeight = _lerpDouble(26.0, 44.0, t)
            .clamp(24.0, math.min(44.0, maxH * 0.30))
            .toDouble();
        final btnRadius = _lerpDouble(8.0, 12.0, t).clamp(8.0, 12.0);
        final bottomPad = pad + _lerpDouble(1.0, 5.0, t);
        final useWideTitle = maxW >= 188;
        final titleCompact = titleWide.replaceAll(' ', '\n');
        final title = useWideTitle ? titleWide : titleCompact;
        final titleLines = useWideTitle ? 1 : (veryCompact ? 1 : 2);
        final showSubtitle = !veryCompact;
        final showChevron = maxW >= 300 && !veryCompact;

        return SizedBox(
          width: maxW,
          height: maxH,
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(radius),
            child: InkWell(
              onTap: onReport,
              borderRadius: BorderRadius.circular(radius),
              splashColor: accent.withValues(alpha: 0.15),
              highlightColor: accent.withValues(alpha: 0.06),
              child: Ink(
                decoration: BoxDecoration(
                  color: surfaceTint,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, bottomPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: iconBox,
                            width: iconBox,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(icon, color: accent, size: iconSize),
                              ),
                            ),
                          ),
                          SizedBox(height: innerGap),
                          Text(
                            title,
                            maxLines: titleLines,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.w800,
                              fontSize: titleSize,
                              height: 1.12,
                              letterSpacing: -0.1,
                            ),
                          ),
                          if (showSubtitle) const SizedBox(height: 3),
                          if (showSubtitle)
                            Text(
                              l10n.entityReportLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: secondaryText,
                                fontWeight: FontWeight.w600,
                                fontSize: (titleSize - 2).clamp(10.0, 14.0),
                                height: 1.1,
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: btnTopGap),
                        child: SizedBox(
                          height: btnHeight,
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: onReport,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: buttonText,
                              elevation: 0,
                              minimumSize: Size(double.infinity, btnHeight),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.symmetric(
                                horizontal: math.max(8.0, pad * 0.55),
                                vertical: 0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(btnRadius),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    l10n.sendReport,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: btnSize,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (showChevron) ...[
                                    SizedBox(width: btnSize * 0.35),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: btnSize + 4,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Parsea los tipos de alerta configurados para una entidad.
List<String> parseEntityReportAlertTypes(Map<String, dynamic> entity) {
  final raw = entity[CommunityFields.reportAlertTypes];
  if (raw is! List) return const [];
  return raw.whereType<String>().where((s) => s.isNotEmpty).toList();
}
