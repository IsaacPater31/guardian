import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:guardian/core/alert_detail_catalog.dart';
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
    final cardHeight =
        (_lerpDouble(142.0, isTablet ? 174.0 : 156.0, shortestT) +
                (isTabletLandscape ? -8.0 : 0.0))
            .clamp(136.0, isTablet ? 182.0 : 164.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(hx, 6, hx, bottomExtra),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxRow),
          child: SizedBox(
            height: cardHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AppleCategoryCard(
                    icon: Icons.eco_rounded,
                    title: 'REPORTE\nAMBIENTAL',
                    subtitle:
                        'Basura, derrames, olores, ruido y calidad del aire.',
                    accent: const Color(0xFF22C55E),
                    surfaceTint: const Color(0xFFF3FBF5),
                    buttonLabel: 'Reportar',
                    onTap: onAmbiental,
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: AppleCategoryCard(
                    icon: Icons.security_rounded,
                    title: 'REPORTE\nPOLICIAL',
                    subtitle:
                        'Hurtos, vandalismo, sospechosos, riñas y amenazas.',
                    accent: const Color(0xFF2563EB),
                    surfaceTint: const Color(0xFFF4F8FF),
                    buttonLabel: 'Reportar',
                    onTap: onPolicial,
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

class AppleCategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color surfaceTint;
  final String buttonLabel;
  final VoidCallback onTap;

  const AppleCategoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.surfaceTint,
    required this.buttonLabel,
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
    final scaleT = _fluidScale(ss, inMin: 300, inMax: 900);
    final iconBox = _lerpDouble(34.0, 48.0, scaleT).clamp(34.0, 48.0);
    final iconSize = _lerpDouble(20.0, 28.0, scaleT).clamp(20.0, 28.0);
    final titleSize = _lerpDouble(12.8, 15.8, scaleT).clamp(12.8, 15.8);
    final bodySize = _lerpDouble(10.3, 12.2, scaleT).clamp(10.3, 12.2);
    final btnSize = _lerpDouble(11.4, 13.0, scaleT).clamp(11.4, 13.0);
    final pad = _lerpDouble(10.0, 14.0, scaleT).clamp(10.0, 14.0);
    final radius = _lerpDouble(12.0, 14.0, scaleT).clamp(12.0, 14.0);
    final tiny = w < 360;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: accent.withValues(alpha: 0.15),
        highlightColor: accent.withValues(alpha: 0.06),
        child: Container(
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
          padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: iconSize),
              ),
              SizedBox(height: tiny ? 6 : 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  fontSize: titleSize,
                  letterSpacing: -0.1,
                ),
              ),
              SizedBox(height: tiny ? 3 : 4),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: tiny ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF4B5563),
                    fontSize: bodySize,
                    height: 1.22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: tiny ? 32 : 35,
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          buttonLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: btnSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
