import 'package:flutter/material.dart';

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
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.people), label: "Comunidades"),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Estadísticas"),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: "Mapa"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
      ],
    );
  }
}
