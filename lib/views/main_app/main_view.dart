import 'package:flutter/material.dart';
import 'package:guardian/controllers/main_app/main_controller.dart';
import 'package:guardian/views/main_app/shared/menu_nav.dart';
import 'package:guardian/views/main_app/home_view.dart';
import 'package:guardian/views/main_app/comunidades_view.dart';
import 'package:guardian/views/main_app/estadisticas_view.dart';
import 'package:guardian/views/main_app/mapa_view.dart';
import 'package:guardian/views/main_app/perfil_view.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final MainController _controller = MainController();

 final List<Widget> _views = const [
  ComunidadesView(),  
  EstadisticasView(),  
  HomeView(),          
  MapaView(),          
  PerfilView(),        
];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _views[_controller.currentIndex],
      bottomNavigationBar: MenuNav(
        currentIndex: _controller.currentIndex,
        onTap: (i) {
          setState(() {
            _controller.currentIndex = i;
          });
        },
      ),
    );
  }
}
