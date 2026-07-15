import 'package:flutter/services.dart';

/// Reproducción local (preview) sin el plugin `audioplayers` — evita
/// [MissingPluginException] si el APK no re-registró plugins (p. ej. hot reload).
class AudioPreviewService {
  AudioPreviewService._();

  static const _channel = MethodChannel('guardian/audio_preview');
  static void Function()? _onComplete;

  static void setCompletionHandler(void Function()? onComplete) {
    _onComplete = onComplete;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'completed') {
        _onComplete?.call();
      }
    });
  }

  static void clearCompletionHandler() {
    _onComplete = null;
    _channel.setMethodCallHandler(null);
  }

  static Future<void> play(String path) async {
    await _channel.invokeMethod<void>('play', <String, dynamic>{'path': path});
  }

  static Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }
}
