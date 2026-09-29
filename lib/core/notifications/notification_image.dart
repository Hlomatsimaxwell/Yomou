import 'dart:io';
import 'dart:typed_data';

/// Fetches a cover image for use as a notification's large icon.
///
/// Shared by the chapter/suggestion notifications and the download
/// notifications so all of them decode, cache and time out identically.
/// Failures are swallowed: a missing cover must never cost us a notification.
class NotificationImage {
  const NotificationImage._();

  /// Bytes for [url], or null when it is absent or unreachable.
  ///
  /// `local://` URLs are read straight off disk (covers saved by the local
  /// directory feature). Everything else is fetched over HTTP with a short
  /// timeout, since a notification is not worth blocking on.
  static Future<Uint8List?> bytesFor(String? url) async {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('local://')) {
      try {
        return await File(url.substring('local://'.length)).readAsBytes();
      } catch (_) {
        return null;
      }
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
