import '../models/alert_model.dart';
import '../services/alert_repository.dart';

class MapController {
  final AlertRepository _alertRepository = AlertRepository();
  
  Stream<List<AlertModel>> getAlertsStream() {
    return _alertRepository.getMapAlertsStream();
  }

  /// Stream de alertas con filtros activos.
  ///
  /// Delega a [AlertRepository.getMapAlertsStreamFiltered].
  Stream<List<AlertModel>> getAlertsStreamFiltered({
    List<String> selectedTypes = const [],
    String filterStatus = 'all',
    String filterDateRange = 'all',
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    return _alertRepository.getMapAlertsStreamFiltered(
      selectedTypes: selectedTypes,
      filterStatus: filterStatus,
      filterDateRange: filterDateRange,
      customStart: customStart,
      customEnd: customEnd,
    );
  }

  Future<List<AlertModel>> getAlertsOnce() async {
    try {
      return await _alertRepository.getMapAlerts();
    } catch (e) {
      print('Error loading alerts: $e');
      return [];
    }
  }
}