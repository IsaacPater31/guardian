import '../models/alert_model.dart';
import '../services/alert_repository.dart';

class MapController {
  final AlertRepository _alertRepository = AlertRepository();
  
  Stream<List<AlertModel>> getAlertsStream() {
    return _alertRepository.getMapAlertsStream();
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