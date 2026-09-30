import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  /// Held for the life of the app: the display monitor keeps a path handler
  /// running and the volume observer a KVO registration, and both are only safe
  /// to tear down deliberately.
  private var displayChannel: DisplayChannel?
  private var volumeChannel: VolumeChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // BGTaskScheduler only delivers a scheduled task to a relaunched app if its
    // launch handler was registered during didFinishLaunching. This app uses the
    // UIScene lifecycle, so the plugin cannot do it for us.
    WorkmanagerPlugin.registerLaunchHandlers()
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // The reader's two native channels. Android implements these in
    // MainActivity.kt; these are the same contracts on iOS so the Dart side
    // needs no platform branch.
    let display = DisplayChannel()
    display.register(with: engineBridge.binaryMessenger)
    displayChannel = display

    let volume = VolumeChannel(messenger: engineBridge.binaryMessenger)
    volume.register()
    volumeChannel = volume
  }
}
