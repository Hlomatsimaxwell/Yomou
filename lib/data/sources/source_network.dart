import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static Future<void> setCookies(String sourceId, {required String value}) async {
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
      captchaAutosolveDisabled:
          prefs.getBool(_captchaOffKeyPrefix + sourceId),
      captchaNotificationsDisabled:
          prefs.getBool(_captchaNotifOffKeyPrefix + sourceId),
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
  /// Identifier used to scope per-source network overrides.
  String get networkSourceId;

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
  Future<String> grabText(
    String url, {
    Map<String, String>? extraHeaders,
    bool useBaseUrl = true,
  }) async {
    try {
      final client = await dio;
      final resolved = useBaseUrl && !url.startsWith('http')
          ? (await effectiveBaseUrl) + url
          : url;
      final res = await client.get<List<int>>(
        resolved,
        options: Options(
          headers: extraHeaders,
          responseType: ResponseType.bytes,
        ),
      );
      if (res.statusCode != 200) return '';
      return String.fromCharCodes(res.data ?? const []);
    } catch (e) {
      debugPrint('${networkSourceId} grabText error: $e');
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
      final res = await client.get<List<int>>(
        url,
        options: Options(
          headers: extraHeaders,
          responseType: ResponseType.bytes,
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
