import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:guardian/views/main_app/widgets/alert_button.dart';

class AlertTriggerSection extends StatelessWidget {
  const AlertTriggerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final shortest = mq.size.shortestSide;
    final landscape = mq.orientation == Orientation.landscape;
    final isTablet = shortest >= 600;
    final isWideWindow = sw >= 840;
    final widthT = ((sw - 320) / (1280 - 320)).clamp(0.0, 1.0);
    final hPad = (8.0 + (18.0 - 8.0) * widthT - (landscape ? 1.0 : 0.0)).clamp(
      8.0,
      18.0,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (isTablet || isWideWindow) {
            final maxRadialWidth = math.min(
              isTablet
                  ? (landscape ? 900.0 : 780.0)
                  : (700.0 + (780.0 - 700.0) * widthT),
              sw * 0.965,
            );
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxRadialWidth),
                child: AlertButton(onPressed: () {}, compactTriggerMode: true),
              ),
            );
          }
          return AlertButton(onPressed: () {}, compactTriggerMode: true);
        },
      ),
    );
  }
}
