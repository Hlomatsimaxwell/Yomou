import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// iOS half of the `com.hlomatsi.yomou/volume` channel.
///
/// This is the one reader feature that does not port cleanly, and the reason
/// is a platform rule rather than a gap in effort: **iOS gives apps no way to
/// intercept or block the volume buttons.** Android hands `dispatchKeyEvent` to
/// the activity, so a press can be swallowed before the system ever sees it.
/// There is no iOS equivalent — no public API returns "the volume button was
/// pressed" — and a press always changes the system volume and shows the HUD.
///
/// What can be done is observe-and-neutralise, which is what most media apps do:
///
///   * an `MPVolumeView` parked off-screen, which suppresses the system HUD,
///   * KVO on `outputVolume`, which is how a press becomes visible at all,
///   * putting the slider back to its armed baseline, so the press is reported
///     to the reader and then undone.
///
/// That reproduces the behaviour the reader wants, but it is a workaround built
/// on behaviour Apple does not document as stable, so it can break in a future
/// iOS release. `setEnabled` therefore reports honestly whether it managed to
/// arm, and the Dart side greys the setting out when it could not, rather than
/// leaving a switch that silently does nothing.
final class VolumeChannel {

    private let channel: FlutterMethodChannel
    private weak var volumeView: MPVolumeView?
    private var slider: UISlider?
    private var observation: NSKeyValueObservation?
    private var armed = false
    private var baseline: Float = 0
    /// Set while the volume is being put back, so the write does not read as a
    /// fresh press and bounce the reader a second time.
    private var restoring = false

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.hlomatsi.yomou/volume",
            binaryMessenger: messenger
        )
    }

    func register() {
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(nil)
                return
            }
            switch call.method {
            case "setEnabled":
                let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
                result(self.setEnabled(enabled))
            case "isAvailable":
                // Probed before the reader arms anything, so it has to build a
                // throwaway view rather than report the armed one. If the
                // slider is not where this iOS version puts it, the workaround
                // no longer applies and the Dart side greys the setting out
                // instead of showing a switch that would do nothing.
                result(Self.canObserveVolumeButtons())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    /// Whether `MPVolumeView` still exposes the slider this workaround needs.
    private static func canObserveVolumeButtons() -> Bool {
        let probe = MPVolumeView(frame: .zero)
        let found = !probe.subviews.compactMap({ $0 as? UISlider }).isEmpty
        probe.removeFromSuperview()
        return found
    }

    @discardableResult
    private func setEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            guard arm() else { return false }
        } else {
            disarm()
        }
        return true
    }

    /// Puts the off-screen view in place and starts watching. Returns false if
    /// the slider could not be found, which is the signal that this iOS version
    /// has changed its view hierarchy and the workaround no longer applies.
    private func arm() -> Bool {
        guard slider == nil else { return true }

        let session = AVAudioSession.sharedInstance()
        // Active so outputVolume actually moves when the buttons are pressed.
        // Failure here is not fatal: the reader still works, the buttons just
        // keep changing the system volume.
        try? session.setActive(true)
        baseline = session.outputVolume

        let view = MPVolumeView(frame: CGRect(x: -4000, y: -4000, width: 1, height: 1))
        view.alpha = 0.0001
        if let window = keyWindow() {
            window.addSubview(view)
        }
        volumeView = view

        guard let found = view.subviews.compactMap({ $0 as? UISlider }).first else {
            volumeView = nil
            return false
        }
        slider = found

        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let self, self.armed, !self.restoring else { return }
            guard let newVolume = change.newValue else { return }

            let up = newVolume > self.baseline
            // Undo the press so the system volume the user chose for their
            // music is not silently overwritten by paging through a chapter.
            self.restoreBaseline()
            self.channel.invokeMethod("volumeKey", arguments: ["up": up])
        }
        armed = true
        return true
    }

    private func disarm() {
        armed = false
        observation?.invalidate()
        observation = nil
        volumeView?.removeFromSuperview()
        volumeView = nil
        slider = nil
    }

    private func restoreBaseline() {
        guard let slider else { return }
        restoring = true
        slider.value = baseline
        // Cleared on the next runloop turn: setting the value synchronously can
        // still deliver the KVO callback before this flag is read.
        DispatchQueue.main.async { [weak self] in
            self?.restoring = false
        }
    }

    private func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first
    }

    func stop() {
        disarm()
    }
}
