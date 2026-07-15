import 'package:guardian/shared/logging/app_logger.dart';
import 'package:guardian/features/alerts/domain/alert_model.dart';
import 'package:guardian/features/alerts/application/alert_service.dart';

/// Map screen adapter: subscribes to filtered alert streams from [AlertService].
///
/// **Why a handler:** isolates map widget code from service/repository types.
class MapHandler {
  final AlertService _alertService = AlertService();

  Stream<List<AlertModel>> getAlertsStream() => _alertService.getMapAlertsStream();

  Stream<List<AlertModel>> getAlertsStreamFiltered({
    List<String> selectedTypes = const [],
    String filterStatus = 'all',
    String filterDateRange = 'all',
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    return _alertService.getMapAlertsStreamFiltered(
      selectedTypes: selectedTypes,
      filterStatus: filterStatus,
      filterDateRange: filterDateRange,
      customStart: customStart,
      customEnd: customEnd,
    );
  }

  Future<List<AlertModel>> getAlertsOnce() async {
    try {
      return await _alertService.getMapAlerts();
    } catch (e) {
      AppLogger.e('MapHandler.getAlertsOnce', e);
      return [];
    }
  }
}
