import 'package:flutter/material.dart';
import 'package:guardian/handlers/main_handler.dart';
import 'package:guardian/core/app_constants.dart';
import 'package:guardian/core/app_logger.dart';
import 'package:guardian/views/main_app/shared/menu_nav.dart';
import 'package:guardian/views/main_app/home_view.dart';
import 'package:guardian/views/main_app/comunidades_view.dart';
import 'package:guardian/views/main_app/estadisticas_view.dart';
import 'package:guardian/views/main_app/mapa_view.dart';
import 'package:guardian/views/main_app/perfil_view.dart';
import 'package:guardian/services/permission_service.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final MainHandler _controller = MainHandler();

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
      AppLogger.d('Requesting essential permissions for Guardian');
      await PermissionService.requestAllPermissionsOnFirstLaunch();

      final essentialGranted = await PermissionService.essentialPermissionsGranted();

      if (essentialGranted) {
        AppLogger.d('Essential permissions granted — Guardian ready');
      } else {
        AppLogger.w('Some essential permissions denied — limited functionality');
        Future.delayed(AppDurations.permissionRetryDelay, () async {
          AppLogger.d('Retrying missing essential permissions');
          await PermissionService.requestMissingPermissions();
        });
      }
    } catch (e) {
      AppLogger.e('_requestPermissionsOnStart', e);
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
