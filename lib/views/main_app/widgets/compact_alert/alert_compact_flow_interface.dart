abstract class AlertCompactFlowInterface {
  bool get isQuickTriggerBusy;
  bool get isEmergencyFlowLocked;

  Future<void> triggerQuickAlert();
  void openEmergencyFlow(String emergencyType);
}
