import 'package:guardian/core/app_constants.dart';

/// Bounds for client-side alert filtering (same presets as map filters).
(DateTime?, DateTime?) alertFilterDateBounds({
  required String range,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  if (range == 'all') return (null, null);
  if (range == 'custom') {
    if (customStart == null && customEnd == null) return (null, null);
    return (customStart, customEnd ?? DateTime.now());
  }

  final now = DateTime.now();
  switch (range) {
    case 'today':
      return (
        DateTime(now.year, now.month, now.day),
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    case 'yesterday':
      final y = now.subtract(const Duration(days: 1));
      return (
        DateTime(y.year, y.month, y.day),
        DateTime(y.year, y.month, y.day, 23, 59, 59),
      );
    case 'week':
      final monday = now.subtract(Duration(days: now.weekday - 1));
      return (DateTime(monday.year, monday.month, monday.day), null);
    case '7days':
      return (now.subtract(const Duration(days: 6)), null);
    case 'month':
      return (DateTime(now.year, now.month, 1), null);
    default:
      return (now.subtract(AppDurations.mapAlertsWindow), null);
  }
}

bool alertTimestampInRange(
  DateTime timestamp,
  String range, {
  DateTime? customStart,
  DateTime? customEnd,
}) {
  if (range == 'all') return true;
  if (range == 'custom') {
    if (customStart == null && customEnd == null) return true;
    if (customStart != null) {
      final s = DateTime(
        customStart.year,
        customStart.month,
        customStart.day,
      );
      if (timestamp.isBefore(s)) return false;
    }
    if (customEnd != null) {
      final eod = DateTime(
        customEnd.year,
        customEnd.month,
        customEnd.day,
        23,
        59,
        59,
      );
      if (timestamp.isAfter(eod)) return false;
    }
    return true;
  }
  final (start, end) = alertFilterDateBounds(
    range: range,
    customStart: customStart,
    customEnd: customEnd,
  );
  if (start != null && timestamp.isBefore(start)) return false;
  if (end != null && timestamp.isAfter(end)) return false;
  return true;
}
