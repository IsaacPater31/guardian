import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:guardian/core/alert_detail_catalog.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';
import 'package:guardian/widgets/adaptive_fit_text.dart';
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
            const Text(
              'Ver mapa',
              style: TextStyle(
                color: Color(0xFF007AFF),
                fontWeight: FontWeight.w700,
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

  double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

  double _lerpDouble(double a, double b, double t) => a + (b - a) * _clamp01(t);

  double _fluidScale(
    double input, {
    required double inMin,
    required double inMax,
  }) {
    if (inMax <= inMin) return 0;
    return _clamp01((input - inMin) / (inMax - inMin));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final shortest = mq.size.shortestSide;
    final isTablet = shortest >= 600;
    final isLandscape = mq.orientation == Orientation.landscape;
    final isTabletLandscape = isTablet && isLandscape;
    final widthT = _fluidScale(w, inMin: 320, inMax: 1280);
    final shortestT = _fluidScale(shortest, inMin: 320, inMax: 900);
    final hx = _lerpDouble(10.0, 22.0, widthT).clamp(10.0, 22.0);
    final baseGap = _lerpDouble(8.0, 14.0, widthT).clamp(8.0, 14.0);
    final gap = isTabletLandscape ? baseGap + 2.0 : baseGap;
    final bottomExtra = mq.padding.bottom > 16
        ? 4.0
        : mq.padding.bottom > 0
        ? 6.0
        : 10.0;
    final maxRow = w >= 720
        ? math.min(
            w * (isTabletLandscape ? 0.94 : 0.92),
            isTablet ? (isTabletLandscape ? 1180.0 : 980.0) : 860.0,
          )
        : double.infinity;
    final cardMinH =
        (_lerpDouble(54.0, isTablet ? 90.0 : 68.0, shortestT) +
                (isTabletLandscape ? -2.0 : 0.0))
            .clamp(52.0, isTablet ? 92.0 : 70.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(hx, 6, hx, bottomExtra),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxRow),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AppleCategoryCard(
                  icon: Icons.eco_rounded,
                  title: l10n.eventualityEnvironmentalTitle,
                  accent: const Color(0xFF34C759),
                  minHeight: cardMinH,
                  onTap: onAmbiental,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: AppleCategoryCard(
                  icon: Icons.local_police_rounded,
                  title: l10n.eventualityPoliceTitle,
                  accent: const Color(0xFF007AFF),
                  minHeight: cardMinH,
                  onTap: onPolicial,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppleCategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final double minHeight;
  final VoidCallback onTap;

  const AppleCategoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.minHeight = 52,
    required this.onTap,
  });

  double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

  double _lerpDouble(double a, double b, double t) => a + (b - a) * _clamp01(t);

  double _fluidScale(
    double input, {
    required double inMin,
    required double inMax,
  }) {
    if (inMax <= inMin) return 0;
    return _clamp01((input - inMin) / (inMax - inMin));
  }

  @override
  Widget build(BuildContext context) {
    final ss = MediaQuery.sizeOf(context).shortestSide;
    final w = MediaQuery.sizeOf(context).width;
    final isTablet = ss >= 600 || w >= 720;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final sizeT = _fluidScale(ss, inMin: 300, inMax: 900);
    final circleFrac = _lerpDouble(
      isLandscape ? 0.095 : 0.102,
      isTablet && isLandscape ? 0.086 : 0.092,
      sizeT,
    );
    final circleD = (ss * circleFrac).clamp(36.0, isTablet ? 54.0 : 48.0);
    final iconSz = (circleD * 0.52).clamp(18.0, 26.0);
    final titleSz = MediaQuery.textScalerOf(context).scale(
      _lerpDouble(13.8, isTablet ? (isLandscape ? 16.1 : 17.0) : 15.2, sizeT),
    );
    final padH = _lerpDouble(9.5, 13.0, sizeT);
    final padV = _lerpDouble(11.0, 14.5, sizeT);

    final circle = Container(
      width: circleD,
      height: circleD,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: accent, size: iconSz),
    );

    final padVEff = math
        .max(padV, (minHeight - circleD) / 2 - 2)
        .clamp(padV, 22.0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: accent.withValues(alpha: 0.15),
          highlightColor: accent.withValues(alpha: 0.06),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padVEff),
            child: LayoutBuilder(
              builder: (context, rowConstraints) {
                final textMaxW = math.max(
                  48.0,
                  rowConstraints.maxWidth - circleD - padH * 2 - 10,
                );
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    circle,
                    const SizedBox(width: 10),
                    Expanded(
                      child: AdaptiveFitText(
                        text: title,
                        maxWidth: textMaxW,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleSz,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.28,
                          color: const Color(0xFF1C1C1E),
                          height: 1.05,
                        ),
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
}
