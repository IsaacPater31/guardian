import 'package:flutter/material.dart';
import 'package:guardian/models/emergency_types.dart';
import 'package:guardian/views/main_app/shared/main_tab_navigation.dart';

class NearbyAlertItemViewData {
  const NearbyAlertItemViewData({
    required this.alertType,
    required this.title,
    required this.distanceLabel,
    required this.timeAgoLabel,
    this.onTap,
  });

  final String alertType;
  final String title;
  final String distanceLabel;
  final String timeAgoLabel;
  final VoidCallback? onTap;
}

class NearbyAlertsSection extends StatelessWidget {
  const NearbyAlertsSection({super.key, required this.items});

  final List<NearbyAlertItemViewData> items;

  static const _titleColor = Color(0xFF1C1C1E);
  static const _linkColor = Color(0xFF007AFF);
  static const _mutedColor = Color(0xFF8E8E93);
  static const _dividerColor = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final compact = sw < 380;
    final hPad = compact ? 10.0 : 14.0;
    final titleSize = compact ? 16.0 : 17.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Alertas cercanas recientes',
                  style: TextStyle(
                    color: _titleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: titleSize,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () =>
                    MainTabNavigation.maybeOf(context)?.openMap(),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Text(
                    'Ver mapa',
                    style: TextStyle(
                      color: _linkColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
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
            child: items.isEmpty ? _buildEmptyState() : _buildAlertStrip(sw),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.grey[500], size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No hay alertas cercanas recientes',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertStrip(double sw) {
    const stripHeight = 72.0;
    final scrollable = sw < 420 && items.length > 1;
    final itemWidth = scrollable ? (sw < 360 ? 132.0 : 148.0) : null;

    final tiles = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        tiles.add(
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: _dividerColor,
            indent: 12,
            endIndent: 12,
          ),
        );
      }
      tiles.add(
        scrollable
            ? SizedBox(
                width: itemWidth,
                child: _NearbyAlertTile(item: items[i]),
              )
            : Expanded(child: _NearbyAlertTile(item: items[i])),
      );
    }

    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: tiles,
      ),
    );

    return SizedBox(
      height: stripHeight,
      child: scrollable
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: row,
            )
          : row,
    );
  }
}

class _NearbyAlertTile extends StatelessWidget {
  const _NearbyAlertTile({required this.item});

  final NearbyAlertItemViewData item;

  @override
  Widget build(BuildContext context) {
    final iconColor = EmergencyTypes.getColor(item.alertType);
    final icon = EmergencyTypes.getIcon(item.alertType);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NearbyAlertsSection._titleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.distanceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NearbyAlertsSection._mutedColor,
                        fontSize: 10.5,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      item.timeAgoLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NearbyAlertsSection._mutedColor,
                        fontSize: 10.5,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
