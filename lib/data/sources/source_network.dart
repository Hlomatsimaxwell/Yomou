import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-source network configuration (the "Kotatsu-style" source settings).
///
/// Stored per source id in SharedPreferences so users can override the
/// user-agent, the domain (mirrors/CDNs) and the HTTP timeouts a source uses,
/// without touching code. Sources built on [DioSource] pick these values up.
class SourceNetworkConfig {
  SourceNetworkConfig({this.userAgent, this.baseUrlOverride, this.timeout});

  static const String _uaKeyPrefix = 'source_network_ua_';
  static const String _domainKeyPrefix = 'source_network_domain_';
  static const String _timeoutKeyPrefix = 'source_network_timeout_';

  final String? userAgent;
  final String? baseUrlOverride;
  final Duration? timeout;

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

  static Future<void> clear({required String sourceId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uaKeyPrefix + sourceId);
    await prefs.remove(_domainKeyPrefix + sourceId);
    await prefs.remove(_timeoutKeyPrefix + sourceId);
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
  Dio? _dio;

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
    final existing = _dio;
    if (existing != null) return existing;

    final config = await SourceNetworkConfig.forSource(networkSourceId);
    final effectiveBaseUrl = (config.baseUrlOverride ?? baseUrl).replaceAll(
      RegExp(r'/$'),
      '',
    );

    final mergedHeaders = <String, dynamic>{
      if (headers != null) ...headers!,
      if (config.userAgent != null) 'User-Agent': config.userAgent,
    };

    final connectedTimeout = config.timeout ?? timeout;
    final client = Dio(
      BaseOptions(
        baseUrl: effectiveBaseUrl,
        headers: mergedHeaders,
        connectTimeout: connectedTimeout,
        receiveTimeout: connectedTimeout,
        sendTimeout: connectedTimeout,
      ),
    );
    return _dio = client;
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
