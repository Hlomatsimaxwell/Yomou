import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/manga_translation.dart';
import 'captcha_gate.dart';
import 'package:yomou/core/diagnostics/diag_log.dart';

/// Per-source network configuration (the "Kotatsu-style" source settings).
///
/// Stored per source id in SharedPreferences so users can override the
/// user-agent, the domain (mirrors/CDNs), the HTTP timeouts a source uses,
/// captured sign-in cookies, CAPTCHA handling and download throttling —
/// without touching code. Sources built on [DioSource] pick these values up.
class SourceNetworkConfig {
  SourceNetworkConfig({
    this.userAgent,
    this.baseUrlOverride,
    this.timeout,
    this.cookies,
    this.captchaAutosolveDisabled,
    this.captchaNotificationsDisabled,
    this.downloadSlowdown,
  });

  static const String _uaKeyPrefix = 'source_network_ua_';
  static const String _domainKeyPrefix = 'source_network_domain_';
  static const String _timeoutKeyPrefix = 'source_network_timeout_';
  static const String _cookiesKeyPrefix = 'source_network_cookies_';
  static const String _captchaOffKeyPrefix = 'source_network_captcha_off_';
  static const String _captchaNotifOffKeyPrefix =
      'source_network_captcha_notif_off_';
  static const String _slowdownKeyPrefix = 'source_network_slowdown_';

  final String? userAgent;
  final String? baseUrlOverride;
  final Duration? timeout;

  /// Captured login cookies as a raw `name=value; name2=value2` header value.
  final String? cookies;

  /// When true the source never tries to solve CAPTCHAs in the background.
  final bool? captchaAutosolveDisabled;

  /// When true no notifications are posted about solving a CAPTCHA.
  final bool? captchaNotificationsDisabled;

  /// When true downloads are throttled to avoid blocking the IP address.
  final bool? downloadSlowdown;

  /// Strips the path/scheme from a user-typed domain (mirrors/link-paste
  /// shortcuts) and returns a well-formed https:// base URL.
  static String normalizeBaseUrl(String input) {
    var value = input.trim();
    if (value.isEmpty) return 'https://';
    if (!value.contains('://')) value = 'https://$value';
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  static Future<void> persist({
    required String sourceId,
    String? userAgent,
    String? baseUrlOverride,
    Duration? timeout,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (userAgent != null) {
      await prefs.setString(_uaKeyPrefix + sourceId, userAgent);
    }
    if (baseUrlOverride != null) {
      await prefs.setString(_domainKeyPrefix + sourceId, baseUrlOverride);
    }
    if (timeout != null) {
      await prefs.setInt(_timeoutKeyPrefix + sourceId, timeout.inMilliseconds);
    }
  }

  /// Sets (or, with a null [value], clears) the base URL override.
  static Future<void> setBaseUrl(String sourceId, {String? value}) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_domainKeyPrefix + sourceId);
    } else {
      await prefs.setString(
        _domainKeyPrefix + sourceId,
        normalizeBaseUrl(value),
      );
    }
  }

  /// Sets (or, with a null [value], clears) the User-Agent override.
  static Future<void> setUserAgent(String sourceId, {String? value}) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_uaKeyPrefix + sourceId);
    } else {
      await prefs.setString(_uaKeyPrefix + sourceId, value.trim());
    }
  }

  /// Stores the cookie header captured after a successful sign-in.
  static Future<void> setCookies(
    String sourceId, {
    required String value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (value.trim().isEmpty) {
      await prefs.remove(_cookiesKeyPrefix + sourceId);
    } else {
      await prefs.setString(_cookiesKeyPrefix + sourceId, value.trim());
    }
  }

  static Future<String?> cookiesFor(String sourceId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_cookiesKeyPrefix + sourceId);
    return (value == null || value.isEmpty) ? null : value;
  }

  static Future<void> clearCookies(String sourceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cookiesKeyPrefix + sourceId);
  }

  static Future<void> setCaptchaAutosolveDisabled(
    String sourceId,
    bool value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_captchaOffKeyPrefix + sourceId, value);
  }

  static Future<void> setCaptchaNotificationsDisabled(
    String sourceId,
    bool value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_captchaNotifOffKeyPrefix + sourceId, value);
  }

  static Future<void> setDownloadSlowdown(String sourceId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_slowdownKeyPrefix + sourceId, value);
  }

  static Future<void> clear({required String sourceId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uaKeyPrefix + sourceId);
    await prefs.remove(_domainKeyPrefix + sourceId);
    await prefs.remove(_timeoutKeyPrefix + sourceId);
    await prefs.remove(_cookiesKeyPrefix + sourceId);
    await prefs.remove(_captchaOffKeyPrefix + sourceId);
    await prefs.remove(_captchaNotifOffKeyPrefix + sourceId);
    await prefs.remove(_slowdownKeyPrefix + sourceId);
  }

  static Future<SourceNetworkConfig> forSource(String sourceId) async {
    final prefs = await SharedPreferences.getInstance();
    return SourceNetworkConfig(
      userAgent: prefs.getString(_uaKeyPrefix + sourceId),
      baseUrlOverride: prefs.getString(_domainKeyPrefix + sourceId),
      timeout: () {
        final ms = prefs.getInt(_timeoutKeyPrefix + sourceId);
        return ms != null ? Duration(milliseconds: ms) : null;
      }(),
      cookies: () {
        final v = prefs.getString(_cookiesKeyPrefix + sourceId);
        return (v == null || v.isEmpty) ? null : v;
      }(),
      captchaAutosolveDisabled: prefs.getBool(_captchaOffKeyPrefix + sourceId),
      captchaNotificationsDisabled: prefs.getBool(
        _captchaNotifOffKeyPrefix + sourceId,
      ),
      downloadSlowdown: prefs.getBool(_slowdownKeyPrefix + sourceId),
    );
  }
}

/// Base class for sources that fetch HTML/JSON over HTTP with Dio.
///
/// Provides a lazily-created [dio] client that applies any user-configured
/// user-agent / domain / timeout overrides (see [SourceNetworkConfig]) on top
/// of the source's own [baseUrl] and [headers], plus a defensive [grabText]
/// used by the HTML parsers.
abstract class DioSource {
  /// Cookie *names* only — values are credentials and never get logged.
  static List<String> _cookieNames(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(';')
        .map((c) => c.split('=').first.trim())
        .where((n) => n.isNotEmpty)
        .toList();
  }

  /// Merges `Set-Cookie` values into this source's stored cookies.
  ///
  /// Already-stored values win, so a Cloudflare clearance earned earlier
  /// survives a response that only sets the application's session cookies.
  Future<void> _storeSetCookies(Map<String, List<String>> headers) async {
    final setCookies = headers['set-cookie'];
    if (setCookies == null || setCookies.isEmpty) return;
    final cfg = await SourceNetworkConfig.forSource(networkSourceId);
    final jar = <String, String>{};

    void absorb(String raw) {
      final pair = raw.split(';').first.trim();
      final eq = pair.indexOf('=');
      if (eq <= 0) return;
      final name = pair.substring(0, eq).trim();
      final value = pair.substring(eq + 1).trim();
      if (name.isEmpty || value.isEmpty) return;
      jar.putIfAbsent(name, () => value);
    }

    for (final part in (cfg.cookies ?? '').split(';')) {
      absorb(part);
    }
    for (final raw in setCookies) {
      absorb(raw);
    }
    if (jar.isEmpty) return;
    await SourceNetworkConfig.setCookies(
      networkSourceId,
      value: jar.entries.map((e) => '${e.key}=${e.value}').join('; '),
    );
  }

  /// Reports a challenge that is about to be raised, with just enough context
  /// to tell "no cookie was sent" apart from "the cookie was sent and
  /// rejected", which look identical from the outside otherwise.
  static void _logChallenge(
    String kind,
    String sourceId,
    String url,
    int? status,
    Map<String, List<String>> headers,
    String body,
    String? cookieHeader,
  ) {
    final names = _cookieNames(cookieHeader);
    final line =
        '$sourceId $kind $url -> $status '
        'sentCookies=${names.isEmpty ? 'none' : names.join(',')} '
        'sentClearance=${names.contains('cf_clearance')} '
        'server=${headers['server']?.first ?? '?'} '
        'mitigated=${headers['cf-mitigated']?.first ?? '-'} '
        'challengeScript=${body.contains('challenges.cloudflare.com')} '
        'bodyLen=${body.length}';
    debugPrint(line);
    diagSoon(line);
  }

  /// Browser user agent for sources that do not pin one of their own.
  ///
  /// The captcha solver presents the same string, because a Cloudflare
  /// clearance cookie only counts for the user agent that earned it.
  static const String defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/138.0.0.0 Mobile Safari/537.36';

  /// Identifier used to scope per-source network overrides.
  String get networkSourceId;

  /// Default language of the source's catalogue, used by the detail screen's
  /// "Translation" row. Sources that publish several languages override this
  /// per manga via [MangaTranslation] lists.
  String get languageCode => 'en';

  /// Alternative translations of a manga published by this source. Single
  /// language sources inherit this empty default.
  Future<List<MangaTranslation>> getTranslations(String mangaId) async => [];

  /// Sources based on [DioSource] offer web sign-in by default; a source that
  /// has no website login (e.g. app-only accounts) overrides this to false.
  bool get supportsSignIn => true;

  /// The URL the in-app source test requests. Defaults to the site's front
  /// page; sources served by a separate API (or a plain SPA) override it with
  /// an endpoint that proves the API itself answers.
  String get testUrl => baseUrl;

  /// Source has no alternative cover artwork by default (subclasses that do
  /// expose alternate covers override this, e.g. MangaDex volume art).
  Future<List<(String url, String? label)>> getAltCovers(String mangaId) async {
    return [];
  }

  /// Effective base URL, possibly overridden by the user's domain override.
  Future<String> get effectiveBaseUrl => SourceNetworkConfig.forSource(
    networkSourceId,
  ).then((c) => c.baseUrlOverride?.replaceAll(RegExp(r'/$'), '') ?? baseUrl);

  String get baseUrl;

  Map<String, String>? get headers;

  Duration? get timeout => const Duration(seconds: 20);

  Future<Dio> get dio async {
    final config = await SourceNetworkConfig.forSource(networkSourceId);
    final effectiveBaseUrl = (config.baseUrlOverride ?? baseUrl).replaceAll(
      RegExp(r'/$'),
      '',
    );

    final mergedHeaders = <String, dynamic>{
      if (headers != null) ...headers!,
      if (config.userAgent != null) 'User-Agent': config.userAgent,
      if (config.cookies != null) 'Cookie': config.cookies,
    };

    final connectedTimeout = config.timeout ?? timeout;
    return Dio(
      BaseOptions(
        baseUrl: effectiveBaseUrl,
        headers: mergedHeaders,
        connectTimeout: connectedTimeout,
        receiveTimeout: connectedTimeout,
        sendTimeout: connectedTimeout,
      ),
    );
  }

  /// Fetches [url] and returns the response body string. Returns an empty
  /// string on non-200 responses or network errors (sources treat '' as a
  /// miss and keep their defensive behaviour).
  ///
  /// Throws [CaptchaRequiredException] when the answer is a Cloudflare
  /// challenge, because that is not a miss the source can retry away: the user
  /// has to clear the challenge once in a browser first.
  Future<String> grabText(
    String url, {
    Map<String, String>? extraHeaders,
    bool useBaseUrl = true,

    /// When set, cookies the response hands out are merged into this source's
    /// stored cookies. Sites that pair a session cookie with a CSRF token need
    /// this: the token is worthless without the session that issued it.
    bool saveCookies = false,
  }) async {
    try {
      final client = await dio;
      final resolved = useBaseUrl && !url.startsWith('http')
          ? (await effectiveBaseUrl) + url
          : url;
      diagSoon('$networkSourceId grabText -> $resolved');
      final res = await client.get<List<int>>(
        resolved,
        options: Options(
          headers: extraHeaders,
          responseType: ResponseType.bytes,
          // Without this Dio throws on 4xx/5xx, and a Cloudflare challenge
          // (a 403 with an HTML body) would never reach the check below.
          validateStatus: (_) => true,
        ),
      );
      final body = String.fromCharCodes(res.data ?? const []);
      if (saveCookies) await _storeSetCookies(res.headers.map);
      if (res.statusCode != 200) {
        if (isCloudflareChallenge(
          status: res.statusCode ?? 0,
          headers: res.headers.map,
          body: body,
        )) {
          _logChallenge(
            'grabText',
            networkSourceId,
            resolved,
            res.statusCode,
            res.headers.map,
            body,
            extraHeaders?['Cookie'] ??
                (await SourceNetworkConfig.forSource(networkSourceId)).cookies,
          );
          throw CaptchaRequiredException(
            sourceId: networkSourceId,
            challengeUrl: resolved,
          );
        }
        return '';
      }
      if (isCloudflareChallenge(
        status: res.statusCode ?? 0,
        headers: res.headers.map,
        body: body,
      )) {
        _logChallenge(
          'grabText',
          networkSourceId,
          resolved,
          res.statusCode,
          res.headers.map,
          body,
          extraHeaders?['Cookie'] ??
              (await SourceNetworkConfig.forSource(networkSourceId)).cookies,
        );
        throw CaptchaRequiredException(
          sourceId: networkSourceId,
          challengeUrl: resolved,
        );
      }
      return body;
    } on CaptchaRequiredException {
      rethrow;
    } catch (e) {
      final line = '$networkSourceId grabText error: $e';
      debugPrint(line);
      diagSoon(line);
      return '';
    }
  }

  /// Posts a form-encoded body and returns the response text, for the sources
  /// whose listings and search live behind a POST endpoint.
  ///
  /// Pass [rawBody] when the form needs repeated keys (`filters[x][]`), which
  /// a map cannot express.
  ///
  /// Challenge pages throw [CaptchaRequiredException] just like [grabText].
  Future<String> postText(
    String url, {
    Map<String, String> form = const {},
    String? rawBody,
    Map<String, String>? extraHeaders,
  }) async {
    try {
      final client = await dio;
      diagSoon('$networkSourceId postText -> $url');
      final res = await client.post<List<int>>(
        url,
        data: rawBody ?? form,
        options: Options(
          headers: rawBody == null
              ? extraHeaders
              : {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  ...?extraHeaders,
                },
          responseType: ResponseType.bytes,
          // See grabText: challenge pages arrive as 403 and must be inspectable.
          validateStatus: (_) => true,
        ),
      );
      final body = String.fromCharCodes(res.data ?? const []);
      if (isCloudflareChallenge(
        status: res.statusCode ?? 0,
        headers: res.headers.map,
        body: body,
      )) {
        _logChallenge(
          'postText',
          networkSourceId,
          url,
          res.statusCode,
          res.headers.map,
          body,
          extraHeaders?['Cookie'] ??
              (await SourceNetworkConfig.forSource(networkSourceId)).cookies,
        );
        throw CaptchaRequiredException(
          sourceId: networkSourceId,
          challengeUrl: url,
        );
      }
      if (res.statusCode != 200) {
        // A short body with a 403 is the site rejecting our session rather
        // than a challenge, so record what we actually presented.
        final sent = extraHeaders?['X-CSRF-TOKEN'];
        final cfg = await SourceNetworkConfig.forSource(networkSourceId);
        final names = _cookieNames(extraHeaders?['Cookie'] ?? cfg.cookies);
        final line =
            '$networkSourceId postText $url -> ${res.statusCode} '
            '(${body.length}b) csrfHeader=${sent != null && sent.isNotEmpty} '
            'cookies=${names.isEmpty ? 'none' : names.join(',')} '
            'body=${body.replaceAll(RegExp(r'\s+'), ' ').substring(0, body.length.clamp(0, 120))}';
        debugPrint(line);
        diagSoon(line);
        return '';
      }
      // A 200 is not automatically useful: the body can be empty, or the
      // request can have been redirected somewhere else entirely.
      if (body.isEmpty || res.realUri.toString() != url) {
        final line =
            '$networkSourceId postText $url -> 200 empty=${body.isEmpty} '
            'finalUri=${res.realUri}';
        debugPrint(line);
        diagSoon(line);
      }
      return body;
    } on CaptchaRequiredException {
      rethrow;
    } catch (e) {
      final line = '$networkSourceId postText error: $e';
      debugPrint(line);
      diagSoon(line);
      return '';
    }
  }

  /// Fetches raw bytes for [url] (used for image downloads with headers).
  Future<List<int>?> grabBytes(
    String url, {
    Map<String, String>? extraHeaders,
  }) async {
    try {
      final config = await SourceNetworkConfig.forSource(networkSourceId);
      if (config.downloadSlowdown ?? false) {
        // Polite pacing so aggressive downloads don't get the IP blocked.
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      final client = await dio;
      diagSoon('$networkSourceId grabBytes -> $url');
      final res = await client.get<List<int>>(
        url,
        options: Options(
          headers: extraHeaders,
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
        ),
      );
      if (res.statusCode != 200) return null;
      return res.data;
    } catch (e) {
      debugPrint('${networkSourceId} grabBytes error: $e');
      return null;
    }
  }
}
