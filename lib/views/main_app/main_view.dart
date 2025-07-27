import 'package:flutter/material.dart';
import 'package:guardian/controllers/main_app/main_controller.dart';
import 'package:guardian/views/main_app/shared/menu_nav.dart';
import 'package:guardian/views/main_app/home_view.dart';
import 'package:guardian/views/main_app/comunidades_view.dart';
import 'package:guardian/views/main_app/estadisticas_view.dart';
import 'package:guardian/views/main_app/mapa_view.dart';
import 'package:guardian/views/main_app/perfil_view.dart';
// IMPORTANTE: importa tu PermissionService
import 'package:guardian/services/permission_service.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final MainController _controller = MainController();

  final List<Widget> _views = const [
    HomeView(),
    ComunidadesView(),
    EstadisticasView(),
    MapaView(),
    PerfilView(),
  ];

  @override
  void initState() {
    super.initState();
    // Solicita permisos al iniciar la vista principal
    PermissionService.requestBasicPermissions();
  }

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
