import 'package:guardian/models/alert_model.dart';

/// Bottom-navigation index for [MainView].
///
/// **Why a handler:** single place for trivial UI state that is not domain data.
class MainHandler {
  int currentIndex = 0;

  /// When set, [MapaView] centers and opens this alert after switching to the map tab.
  AlertModel? mapFocusAlert;
}
