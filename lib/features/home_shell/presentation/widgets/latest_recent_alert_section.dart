import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

class LatestRecentAlertSection extends StatelessWidget {
  const LatestRecentAlertSection({
    super.key,
    required this.hasAlert,
    required this.child,
  });

  final bool hasAlert;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final t = ((screenWidth - 320) / (900 - 320)).clamp(0.0, 1.0);
    final horizontalMargin = (10.0 + (16.0 - 10.0) * t).clamp(10.0, 16.0);
    final sectionPadding = (10.0 + (14.0 - 10.0) * t).clamp(10.0, 14.0);
    final titleSize = (13.0 + (14.0 - 13.0) * t).clamp(13.0, 14.0);
    final iconSize = (15.0 + (17.0 - 15.0) * t).clamp(15.0, 17.0);
    final iconPad = (5.0 + (6.0 - 5.0) * t).clamp(5.0, 6.0);
    final headerGap = (6.0 + (10.0 - 6.0) * t).clamp(6.0, 10.0);

    return Container(
      margin: EdgeInsets.fromLTRB(horizontalMargin, 6, horizontalMargin, 6),
      padding: EdgeInsets.fromLTRB(sectionPadding, 8, sectionPadding, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(iconPad),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: const Color(0xFF1976D2),
                  size: iconSize,
                ),
              ),
              SizedBox(width: headerGap),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.recentAlerts,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasAlert)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '1',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
