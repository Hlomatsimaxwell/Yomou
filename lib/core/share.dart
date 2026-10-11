import 'package:flutter/services.dart';

/// The Android system "share with…" chooser. The app's own share sheet still
/// decides *which* link to send; this hands that link to Android so the user
/// can send it to WhatsApp, email, or anywhere else in one tap.
const MethodChannel _channel = MethodChannel('com.hlomatsi.yomou/share');

/// Opens the system share sheet with [text] as its payload. Returns false
/// when the platform can't share (tests, hosts without the native handler).
Future<bool> shareText(String text) async {
  try {
    return await _channel.invokeMethod<bool>('shareText', {'text': text}) ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}