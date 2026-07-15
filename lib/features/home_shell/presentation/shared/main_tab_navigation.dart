import 'package:flutter/material.dart';
import 'package:guardian/features/alerts/domain/alert_model.dart';

/// Exposes main bottom-nav tab switching to descendants (e.g. Home "Ver mapa").
class MainTabNavigation extends InheritedWidget {
  const MainTabNavigation({
    super.key,
    required this.currentIndex,
    required this.goToTab,
    required this.openMap,
    required this.openMapOnAlert,
    required super.child,
  });

  static const int homeIndex = 0;
  static const int communitiesIndex = 1;
  static const int statisticsIndex = 2;
  static const int mapIndex = 3;
  static const int profileIndex = 4;

  final int currentIndex;
  final ValueChanged<int> goToTab;
  final VoidCallback openMap;
  final ValueChanged<AlertModel> openMapOnAlert;

  static MainTabNavigation? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainTabNavigation>();
  }

  @override
  bool updateShouldNotify(MainTabNavigation oldWidget) =>
      currentIndex != oldWidget.currentIndex;
}
