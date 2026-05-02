import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, AVAudioPlayerDelegate {
  private var audioPreviewPlayer: AVAudioPlayer?
  private var audioPreviewChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      let ch = FlutterMethodChannel(
        name: "guardian/audio_preview",
        binaryMessenger: controller.binaryMessenger
      )
      audioPreviewChannel = ch
      ch.setMethodCallHandler { [weak self] call, result in
        self?.handleAudioPreview(call: call, result: result)
      }
    }
    return ok
  }

  private func handleAudioPreview(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "play":
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(FlutterError(code: "BAD_ARGS", message: "path required", details: nil))
        return
      }
      audioPreviewPlayer?.stop()
      let url = URL(fileURLWithPath: path)
      do {
        let p = try AVAudioPlayer(contentsOf: url)
        p.delegate = self
        audioPreviewPlayer = p
        p.play()
        result(true)
      } catch {
        result(FlutterError(code: "PLAY_FAILED", message: error.localizedDescription, details: nil))
      }
    case "stop":
      audioPreviewPlayer?.stop()
      audioPreviewPlayer = nil
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    audioPreviewPlayer = nil
    audioPreviewChannel?.invokeMethod("completed", arguments: nil)
  }
}
