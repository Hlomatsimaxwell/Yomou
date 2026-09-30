import Flutter
import Network
import UIKit

/// iOS half of the `com.hlomatsi.yomou/display` channel.
///
/// Two of the three Android display features port cleanly. "Keep screen on"
/// becomes `isIdleTimerDisabled`, which has the same scope — the app stops
/// idling while a chapter is open and the flag is cleared on exit, so it is
/// never left set for the rest of the session.
///
/// "Only on Wi-Fi" preloading maps to the path monitor. Android reports
/// `NET_CAPABILITY_NOT_METERED`; iOS has no such capability, but
/// `NWPath.isExpensive` (cellular, or a hotspot) and `isConstrained` (Low Data
/// Mode) describe the same thing from the other direction. Unmetered means
/// neither, and Wi-Fi is not special-cased, so Ethernet behaves like Wi-Fi
/// does on Android.
final class DisplayChannel {

    /// The path monitor delivers asynchronously, so the first `isUnmetered`
    /// call can arrive before any callback has run. Defaulting to `true`
    /// matches the Dart side's fallback: a probe that has not answered yet
    /// must not silently stop preloading.
    private var unmetered = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.hlomatsi.yomou.display.path")

    func register(with messenger: FlutterBinaryMessenger) {
        // The monitor starts here rather than lazily so the cached answer is
        // warm by the time the reader first asks.
        monitor.pathUpdateHandler = { [weak self] path in
            self?.unmetered = !path.isExpensive && !path.isConstrained
        }
        monitor.start(queue: queue)

        let channel = FlutterMethodChannel(
            name: "com.hlomatsi.yomou/display",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(nil)
                return
            }
            switch call.method {
            case "setKeepScreenOn":
                let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
                // isIdleTimerDisabled is UIKit state and must be touched on the
                // main thread; a method channel handler is not guaranteed to be
                // there.
                if Thread.isMainThread {
                    UIApplication.shared.isIdleTimerDisabled = enabled
                } else {
                    DispatchQueue.main.async {
                        UIApplication.shared.isIdleTimerDisabled = enabled
                    }
                }
                result(true)
            case "isUnmetered":
                result(self.unmetered)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func stop() {
        monitor.cancel()
    }
}
