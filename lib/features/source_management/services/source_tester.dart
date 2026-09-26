import 'package:dio/dio.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/data/sources/source_network.dart';

/// The outcome of a one-shot connectivity check against a source.
///
/// Sources swallow their network errors and return an empty list, so a blank
/// browse screen is indistinguishable from a dead source. This runs the real
/// request and reports what the server actually answered, which separates the
/// usual causes:
///
/// * no status at all -> DNS/connection/timeout (offline, blocked host, VPN)
/// * 403 / 429 / 503  -> anti-bot, geo or rate-limit block
/// * 200 but 0 titles -> the source parses, the app's parsing or ids are wrong
class SourceTestResult {
  /// The URL that was requested.
  final String url;

  /// HTTP status code, or null when the request never completed.
  final int? status;

  final String? contentType;
  final String? server;
  final String? error;

  /// First slice of the response body (an anti-bot page shows up here).
  final String bodyHead;

  /// How many titles a real browse call returned.
  final int? listingCount;

  /// How long the raw request took.
  final int elapsedMs;

  const SourceTestResult({
    required this.url,
    this.status,
    this.contentType,
    this.server,
    this.error,
    this.bodyHead = '',
    this.listingCount,
    required this.elapsedMs,
  });

  /// A 2xx response that actually carried something.
  bool get reachable =>
      status != null && status! >= 200 && status! < 400 && error == null;

  /// A challenge/denial response rather than a missing site.
  bool get blocked =>
      status == 403 ||
      status == 429 ||
      status == 401 ||
      status == 503 ||
      (bodyHead.toLowerCase().contains('captcha')) ||
      (bodyHead.toLowerCase().contains('just a moment')) ||
      (bodyHead.toLowerCase().contains('cloudflare'));

  /// Verdict for the user, in plain words.
  String get verdict {
    if (error != null) return 'No response';
    if (blocked) return 'Blocked (anti-bot)';
    if (!reachable) return 'HTTP error';
    if (listingCount != null && listingCount == 0) {
      return 'Reachable, but no titles parsed';
    }
    return 'Working';
  }
}

/// Runs [source]'s test request and then one real browse call.
Future<SourceTestResult> testMangaSource(MangaSource source) async {
  final stopwatch = Stopwatch()..start();
  // `DioSource` is a mixin-like helper unrelated to `MangaSource`, so the cast
  // is explicit rather than a type promotion.
  final dioSource = source is DioSource ? source as DioSource : null;
  final url = dioSource?.testUrl ?? source.baseUrl;

  int? status;
  String? contentType;
  String? server;
  String? error;
  var bodyHead = '';

  try {
    // Reuse the source's own client so the test reflects the real request:
    // user-agent and cookie overrides, timeouts and the domain override.
    final client = dioSource != null
        ? await dioSource.dio
        : Dio(BaseOptions(baseUrl: source.baseUrl, headers: source.headers));
    final response = await client.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        // Report 4xx/5xx as data instead of throwing, so a 403 is visible.
        validateStatus: (_) => true,
      ),
    );
    status = response.statusCode;
    contentType = response.headers.value('content-type');
    server = response.headers.value('server');
    bodyHead = _head(response.data ?? '');
  } catch (e) {
    error = e.toString();
  }
  stopwatch.stop();

  // A real browse call, so "reachable but broken" is visible too.
  int? listingCount;
  try {
    listingCount = (await source.getPopularManga(page: 1)).length;
  } catch (e) {
    error ??= e.toString();
  }

  return SourceTestResult(
    url: url,
    status: status,
    contentType: contentType,
    server: server,
    error: error,
    bodyHead: bodyHead,
    listingCount: listingCount,
    elapsedMs: stopwatch.elapsedMilliseconds,
  );
}

String _head(String body, {int max = 600}) {
  final collapsed = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  return collapsed.length <= max ? collapsed : '${collapsed.substring(0, max)}…';
}
