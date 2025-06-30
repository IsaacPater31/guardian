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
      selectedItemColor: const Color(0xFFD32F2F),
      unselectedItemColor: const Color(0xFF757575),
      type: BottomNavigationBarType.fixed,
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
