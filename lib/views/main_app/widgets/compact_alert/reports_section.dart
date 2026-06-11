import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:guardian/core/alert_detail_catalog.dart';
import 'package:guardian/views/main_app/shared/main_tab_navigation.dart';
import 'package:guardian/views/main_app/widgets/compact_alert/alert_compact_flow_interface.dart';

class ReportsSection extends StatelessWidget {
  const ReportsSection({
    super.key,
    required this.titleSize,
    required this.topGap,
    required this.rowGap,
    required this.flow,
  });

  final double titleSize;
  final double topGap;
  final double rowGap;
  final AlertCompactFlowInterface flow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topGap),
        Row(
          children: [
            Expanded(
              child: Text(
                'Reportes',
                style: TextStyle(
                  color: const Color(0xFF1C1C1E),
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => MainTabNavigation.maybeOf(context)?.openMap(),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Text(
                  'Ver mapa',
                  style: TextStyle(
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: rowGap),
        EventualityBottomStrip(
          onAmbiental: () {
            if (flow.isEmergencyFlowLocked) return;
            flow.openEmergencyFlow(AlertDetailCatalog.environmental);
          },
          onPolicial: () {
            if (flow.isEmergencyFlowLocked) return;
            flow.openEmergencyFlow(AlertDetailCatalog.police);
          },
        ),
      ],
    );
  }
}

class EventualityBottomStrip extends StatelessWidget {
  final VoidCallback onAmbiental;
  final VoidCallback onPolicial;

  const EventualityBottomStrip({
    super.key,
    required this.onAmbiental,
    required this.onPolicial,
  });

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

  @override
  Widget build(BuildContext context) {
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
              final slotW = math.max(120.0, (rowW - gap) / 2);
              final cardHeight = _resolveCardHeight(
                slotWidth: slotW,
                shortestSide: shortest,
                isTablet: isTablet,
              );

              return SizedBox(
                height: cardHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: AppleCategoryCard(
                        slotWidth: slotW,
                        cardHeight: cardHeight,
                        icon: Icons.eco_rounded,
                        titleCompact: 'REPORTE\nAMBIENTAL',
                        titleWide: 'REPORTE AMBIENTAL',
                        accent: const Color(0xFF22C55E),
                        surfaceTint: const Color(0xFFF3FBF5),
                        buttonLabel: 'Reportar',
                        onTap: onAmbiental,
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: AppleCategoryCard(
                        slotWidth: slotW,
                        cardHeight: cardHeight,
                        icon: Icons.security_rounded,
                        titleCompact: 'REPORTE\nPOLICIAL',
                        titleWide: 'REPORTE POLICIAL',
                        accent: const Color(0xFF2563EB),
                        surfaceTint: const Color(0xFFF4F8FF),
                        buttonLabel: 'Reportar',
                        onTap: onPolicial,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AppleCategoryCard extends StatelessWidget {
  const AppleCategoryCard({
    super.key,
    required this.slotWidth,
    required this.cardHeight,
    required this.icon,
    required this.titleCompact,
    required this.titleWide,
    required this.accent,
    required this.surfaceTint,
    required this.buttonLabel,
    required this.onTap,
  });

  final double slotWidth;
  final double cardHeight;
  final IconData icon;
  final String titleCompact;
  final String titleWide;
  final Color accent;
  final Color surfaceTint;
  final String buttonLabel;
  final VoidCallback onTap;

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

  @override
  Widget build(BuildContext context) {
    final slotT = _fluidScale(slotWidth, inMin: 148, inMax: 420);
    final heightT = _fluidScale(cardHeight, inMin: 134, inMax: 210);
    final t = math.min(slotT, heightT);

    final pad = _lerpDouble(10.0, 16.0, t).clamp(10.0, 16.0);
    final radius = _lerpDouble(12.0, 16.0, t).clamp(12.0, 16.0);
    final iconBox = _lerpDouble(28.0, 52.0, t)
        .clamp(math.min(26.0, cardHeight * 0.22), 52.0)
        .toDouble();
    final iconSize = iconBox * 0.56;
    final titleSize = _lerpDouble(11.0, 16.0, t).clamp(11.0, 16.0);
    final btnSize = _lerpDouble(10.5, 14.0, t).clamp(10.5, 14.0);
    final innerGap = _lerpDouble(6.0, 12.0, t).clamp(6.0, 12.0);
    final btnTopGap = _lerpDouble(8.0, 14.0, t).clamp(8.0, 14.0);
    final btnHeight = _lerpDouble(32.0, 44.0, t)
        .clamp(30.0, math.min(44.0, cardHeight * 0.28))
        .toDouble();
    final btnRadius = _lerpDouble(9.0, 12.0, t).clamp(9.0, 12.0);
    final bottomPad = pad + _lerpDouble(2.0, 5.0, t);
    final useWideTitle = slotWidth >= 188;
    final title = useWideTitle ? titleWide : titleCompact;
    final titleLines = useWideTitle ? 1 : 2;
    final showChevron = slotWidth >= 300;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : slotWidth;

        return SizedBox(
          width: maxW,
          height: constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : cardHeight,
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(radius),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              splashColor: accent.withValues(alpha: 0.15),
              highlightColor: accent.withValues(alpha: 0.06),
              child: Ink(
                decoration: BoxDecoration(
                  color: surfaceTint,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.25),
                    width: 0.9,
                  ),
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
                              color: accent,
                              fontWeight: FontWeight.w900,
                              fontSize: titleSize,
                              height: 1.12,
                              letterSpacing: -0.1,
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
                            onPressed: onTap,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
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
                                    buttonLabel,
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
