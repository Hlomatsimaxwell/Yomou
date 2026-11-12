import Flutter
import UIKit

/// iOS half of the `com.hlomatsi.yomou/google_config` channel.
///
/// GoogleSignIn raises an Objective-C exception (which Dart cannot catch) when
/// `GIDClientID` is missing from Info.plist, so the Dart side asks here before
/// it ever touches the plugin.
final class GoogleConfigChannel {

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "com.hlomatsi.yomou/google_config",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "isSignInConfigured":
                // A placeholder left in a template still counts as missing: the
                // native SDK would try to use it and fail on launch of the flow.
                guard
                    let rawID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
                else {
                    result(false)
                    return
                }
                let clientID = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
                guard
                    !clientID.isEmpty,
                    !clientID.contains("<"),
                    !clientID.uppercased().contains("YOUR_")
                else {
                    result(false)
                    return
                }
                // The browser hands the OAuth result back through the reversed
                // client ID URL scheme. Without it the flow dead-ends, so treat
                // the build as unconfigured too.
                result(Self.hasReversedClientScheme(clientID))
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func hasReversedClientScheme(_ clientID: String) -> Bool {
        guard let suffix = clientID.range(of: ".apps.googleusercontent.com") else {
            return false
        }
        let reversed = "com.googleusercontent.apps.\(clientID[..<suffix.lowerBound])"
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }
        return urlTypes.contains { type in
            (type["CFBundleURLSchemes"] as? [String])?.contains(reversed) == true
        }
    }
}
