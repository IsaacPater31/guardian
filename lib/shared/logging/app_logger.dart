import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

/// Lightweight application-wide logger.
///
/// All logging in the app should go through this class instead of calling
/// [print] directly. In release builds, log output is suppressed.
///
/// Usage:
/// ```dart
/// AppLogger.d('Community loaded: $id');      // debug / informational
/// AppLogger.w('Permission denied');           // warning
/// AppLogger.e('Failed to save alert', err);  // error
/// ```
abstract final class AppLogger {
  /// Logs an informational / debug message (only in debug mode).
  static void d(String message) {
    if (kDebugMode) debugPrint('[DEBUG] $message');
  }

  /// Logs a warning message (only in debug mode).
  static void w(String message) {
    if (kDebugMode) debugPrint('[WARN]  $message');
  }

  /// Logs an error message with an optional [error] object (only in debug mode).
  static void e(String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message${error != null ? ' — $error' : ''}');
    }
  }
}
