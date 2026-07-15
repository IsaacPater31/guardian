import 'package:flutter/material.dart';
import 'package:guardian/features/home_shell/application/main_handler.dart';
import 'package:guardian/features/alerts/domain/alert_model.dart';
import 'package:guardian/shared/config/app_constants.dart';
import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/home_shell/presentation/shared/main_tab_navigation.dart';
import 'package:guardian/features/home_shell/presentation/shared/menu_nav.dart';
import 'package:guardian/features/home_shell/presentation/home_view.dart';
import 'package:guardian/features/communities/presentation/comunidades_view.dart';
import 'package:guardian/features/home_shell/presentation/estadisticas_view.dart';
import 'package:guardian/features/map/presentation/mapa_view.dart';
import 'package:guardian/features/auth/presentation/perfil_view.dart';
import 'package:guardian/features/home_shell/application/permission_service.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final MainHandler _controller = MainHandler();

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

  void _goToTab(int index) {
    setState(() {
      _controller.currentIndex = index;
    });
  }

  void _openMap() {
    setState(() {
      _controller.mapFocusAlert = null;
      _controller.currentIndex = MainTabNavigation.mapIndex;
    });
  }

  void _openMapOnAlert(AlertModel alert) {
    setState(() {
      _controller.mapFocusAlert = alert;
      _controller.currentIndex = MainTabNavigation.mapIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapFocus = _controller.mapFocusAlert;

    return MainTabNavigation(
      currentIndex: _controller.currentIndex,
      goToTab: _goToTab,
      openMap: _openMap,
      openMapOnAlert: _openMapOnAlert,
      child: Scaffold(
        body: IndexedStack(
          index: _controller.currentIndex,
          children: [
            const HomeView(),
            const ComunidadesView(),
            const EstadisticasView(),
            MapaView(
              key: ValueKey(mapFocus?.id ?? 'map-default'),
              selectedAlert: mapFocus,
            ),
            const PerfilView(),
          ],
        ),
        bottomNavigationBar: MenuNav(
          currentIndex: _controller.currentIndex,
          onTap: _goToTab,
        ),
      ),
    );
  }
}
