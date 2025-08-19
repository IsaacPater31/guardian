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
    // Solicita todos los permisos al iniciar la vista principal
    _requestPermissionsOnStart();
  }

  Future<void> _requestPermissionsOnStart() async {
    try {
      // Solicitar permisos básicos del sistema (Google/Apple)
      print('🔐 Requesting basic permissions...');
      await PermissionService.requestBasicPermissions();
      
      // Verificar si tenemos todos los permisos
      final allGranted = await PermissionService.allGranted();
      print('✅ Permissions granted: $allGranted');
      
      if (allGranted) {
        print('✅ All permissions granted - Guardian is ready!');
      } else {
        print('⚠️ Some permissions were denied - Guardian may have limited functionality');
      }
    } catch (e) {
      print('❌ Error requesting permissions: $e');
    }
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
