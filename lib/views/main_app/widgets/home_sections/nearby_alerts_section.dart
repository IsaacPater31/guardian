import 'package:flutter/material.dart';
import 'package:guardian/models/emergency_types.dart';

class NearbyAlertItemViewData {
  const NearbyAlertItemViewData({
    required this.alertType,
    required this.distanceLabel,
    required this.timeAgoLabel,
  });

  final String alertType;
  final String distanceLabel;
  final String timeAgoLabel;
}

class NearbyAlertsSection extends StatelessWidget {
  const NearbyAlertsSection({super.key, required this.items});

  final List<NearbyAlertItemViewData> items;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final compact = sw < 380;
    final columns = sw < 360
        ? 1
        : sw < 620
        ? 2
        : 3;
    final tileAspect = sw < 360
        ? 3.0
        : sw < 460
        ? 1.55
        : sw < 620
        ? 1.7
        : 1.85;

    return Container(
      margin: EdgeInsets.fromLTRB(compact ? 10 : 14, 8, compact ? 10 : 14, 10),
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        10,
        compact ? 10 : 12,
        10,
      ),
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
              Expanded(
                child: Text(
                  'Alertas cerca de ti',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 16.0 : 17.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No hay alertas cercanas hoy',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns < items.length ? columns : items.length,
                mainAxisSpacing: compact ? 8 : 10,
                crossAxisSpacing: compact ? 8 : 10,
                childAspectRatio: tileAspect,
              ),
              itemBuilder: (context, i) {
                final item = items[i];
                final iconColor = EmergencyTypes.getColor(item.alertType);
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 10,
                    vertical: compact ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        EmergencyTypes.getIcon(item.alertType),
                        color: iconColor,
                        size: compact ? 20 : 24,
                      ),
                      SizedBox(height: compact ? 4 : 5),
                      Text(
                        EmergencyTypes.getTranslatedType(
                          item.alertType,
                          context,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 10.0 : 11.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.distanceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: compact ? 9.2 : 10.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.timeAgoLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: compact ? 9.2 : 10.0,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
