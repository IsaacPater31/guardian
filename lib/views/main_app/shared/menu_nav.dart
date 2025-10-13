import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

class MenuNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MenuNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF1F2937), // Azul Guardian
      unselectedItemColor: const Color(0xFF757575), // Gris
      selectedIconTheme: const IconThemeData(size: 28), // Un poco más grande el ícono seleccionado
      unselectedIconTheme: const IconThemeData(size: 24),
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      items: [
        BottomNavigationBarItem(icon: const Icon(Icons.home), label: AppLocalizations.of(context)!.home),
        BottomNavigationBarItem(icon: const Icon(Icons.people), label: AppLocalizations.of(context)!.communities),
        BottomNavigationBarItem(icon: const Icon(Icons.bar_chart), label: AppLocalizations.of(context)!.statistics),
        BottomNavigationBarItem(icon: const Icon(Icons.map), label: AppLocalizations.of(context)!.map),
        BottomNavigationBarItem(icon: const Icon(Icons.person), label: AppLocalizations.of(context)!.profile),
      ],
    );
  }
}
