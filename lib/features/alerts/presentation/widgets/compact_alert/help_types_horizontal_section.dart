import 'package:flutter/material.dart';
import 'package:guardian/features/alerts/domain/emergency_types.dart';
import 'package:guardian/features/alerts/presentation/widgets/compact_alert/alert_compact_flow_interface.dart';

class HelpTypesHorizontalSection extends StatelessWidget {
  const HelpTypesHorizontalSection({
    super.key,
    required this.title,
    required this.titleSize,
    required this.topGap,
    required this.rowGap,
    required this.cardHeight,
    required this.cardWidth,
    required this.compact,
    required this.quickTypes,
    required this.flow,
  });

  final String title;
  final double titleSize;
  final double topGap;
  final double rowGap;
  final double cardHeight;
  final double cardWidth;
  final bool compact;
  final List<String> quickTypes;
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
                title,
                style: TextStyle(
                  color: const Color(0xFF1C1C1E),
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: rowGap),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: quickTypes.length,
            separatorBuilder: (_, __) => SizedBox(width: rowGap),
            itemBuilder: (_, i) {
              final type = quickTypes[i];
              final data = EmergencyTypes.getTypeByName(type);
              if (data == null) return const SizedBox.shrink();
              return SizedBox(
                width: cardWidth,
                child: QuickTypeTapCard(
                  icon: data['icon'] as IconData,
                  color: data['color'] as Color,
                  title: EmergencyTypes.getTranslatedType(type, context),
                  compact: compact,
                  onTap: () {
                    if (flow.isEmergencyFlowLocked) return;
                    flow.openEmergencyFlow(type);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class QuickTypeTapCard extends StatelessWidget {
  const QuickTypeTapCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;
  final bool compact;

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
    final w = MediaQuery.of(context).size.width;
    final t = _fluidScale(w, inMin: 300, inMax: 900);
    final iconSize = _lerpDouble(
      compact ? 27.0 : 30.0,
      34.0,
      t,
    ).clamp(compact ? 27.0 : 30.0, 34.0);
    final labelSize = _lerpDouble(
      compact ? 11.0 : 11.8,
      12.8,
      t,
    ).clamp(compact ? 11.0 : 11.8, 12.8);
    final padH = _lerpDouble(7.0, 10.0, t).clamp(7.0, 10.0);
    final padV = _lerpDouble(8.0, 11.0, t).clamp(8.0, 11.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E5EA)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: compact ? 40 : 46,
                height: compact ? 40 : 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: iconSize),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: labelSize,
                  height: 1.14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
