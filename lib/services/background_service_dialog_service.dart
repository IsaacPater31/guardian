import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

/// Servicio para manejar diálogos de servicios en segundo plano
/// Proporciona una capa de abstracción para mostrar diálogos específicos por plataforma
class BackgroundServiceDialogService {
  static final BackgroundServiceDialogService _instance = BackgroundServiceDialogService._internal();
  factory BackgroundServiceDialogService() => _instance;
  BackgroundServiceDialogService._internal();

  /// Muestra el diálogo apropiado según la plataforma
  static void showServiceDialog(
    BuildContext context, {
    required bool isServiceRunning,
    required bool isServiceLoading,
    required VoidCallback onToggleService,
  }) {
    if (Platform.isAndroid) {
      _showAndroidServiceDialog(
        context,
        isServiceRunning: isServiceRunning,
        isServiceLoading: isServiceLoading,
        onToggleService: onToggleService,
      );
    } else if (Platform.isIOS) {
      _showIOSServiceDialog(context);
    } else {
      _showDefaultServiceDialog(context);
    }
  }

  /// Diálogo específico para Android con controles de servicio
  static void _showAndroidServiceDialog(
    BuildContext context, {
    required bool isServiceRunning,
    required bool isServiceLoading,
    required VoidCallback onToggleService,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isServiceRunning ? Icons.notifications_active : Icons.notifications_off,
                color: isServiceRunning ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(isServiceRunning ? 'Servicio Activo' : 'Servicio Inactivo'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isServiceRunning 
                  ? 'Guardian está escuchando alertas en segundo plano. Verás una notificación persistente en el panel de notificaciones.'
                  : '¿Deseas activar el servicio en segundo plano para recibir alertas de emergencia?',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isServiceRunning ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isServiceRunning ? Colors.green[200]! : Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isServiceRunning ? Icons.check_circle : Icons.info,
                      color: isServiceRunning ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isServiceRunning 
                          ? 'Servicio funcionando correctamente'
                          : 'El servicio te permitirá recibir alertas incluso con la app cerrada',
                        style: TextStyle(
                          fontSize: 14,
                          color: isServiceRunning ? Colors.green[700] : Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onToggleService();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isServiceRunning ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(isServiceRunning ? 'Detener' : 'Activar'),
            ),
          ],
        );
      },
    );
  }

  /// Diálogo específico para iOS con información de push notifications
  static void _showIOSServiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                CupertinoIcons.bell_fill,
                color: CupertinoColors.systemBlue,
              ),
              const SizedBox(width: 8),
              const Text('Notificaciones Push'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'En iOS, Guardian usa notificaciones push para alertarte sobre emergencias.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: CupertinoColors.systemBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.info_circle_fill,
                      color: CupertinoColors.systemBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Las notificaciones push están siempre activas y no requieren configuración adicional.',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: CupertinoColors.systemBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  /// Diálogo para otras plataformas
  static void _showDefaultServiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              const Text('Servicios en Segundo Plano'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Los servicios en segundo plano no están disponibles en esta plataforma.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  /// Obtiene el icono apropiado según el estado del servicio
  static IconData getServiceIcon({
    required bool isServiceLoading,
    required bool isServiceRunning,
  }) {
    if (isServiceLoading) {
      return Icons.hourglass_empty;
    } else if (isServiceRunning) {
      return Icons.notifications_active;
    } else {
      return Icons.notifications_outlined;
    }
  }

  /// Obtiene el color del icono según el estado del servicio
  static Color getServiceIconColor({
    required bool isServiceLoading,
    required bool isServiceRunning,
  }) {
    if (isServiceLoading) {
      return Colors.grey;
    } else if (isServiceRunning) {
      return Colors.green;
    } else {
      return const Color(0xFF1A1A1A);
    }
  }
}
