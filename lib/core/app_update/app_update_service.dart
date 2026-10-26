import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Holds the latest available APK download URL and version name, or null
/// when the app is up to date (or the check hasn't completed yet).
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.apkUrl,
  });
  final String version;
  final String apkUrl;
}

/// Checks GitHub releases for a newer Yomou build and exposes the result.
///
/// Runs once per app launch (lazy, cached by Riverpod). Respects the
/// `github_updates_repo` convention; falls back to Hlomatsimaxwell/Yomou.
class AppUpdateService {
  AppUpdateService._();

  static const _repo = 'Hlomatsimaxwell/Yomou';
  static const _api = 'https://api.github.com/repos/$_repo/releases/latest';

  /// Returns update info when the published release is newer than the
  /// running build, otherwise null.
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // e.g. "1.1.7"
      final dio = Dio();
      final res = await dio.get<Map<String, dynamic>>(_api);
      if (res.statusCode != 200 || res.data == null) return null;
      final tag = (res.data!['tag_name'] as String? ?? '').replaceFirst('v', '');
      if (!_isNewer(tag, currentVersion)) return null;

      // Pick the APK matching the running binary's architecture. Default
      // to the universal build if we can't tell.
      final arch = _deviceArch();
      final assets = (res.data!['assets'] as List?) ?? const [];
      Map<String, dynamic>? match;
      for (final a in assets) {
        final name = (a as Map<String, dynamic>)['name'] as String? ?? '';
        if (!name.toLowerCase().endsWith('.apk')) continue;
        if (arch == 'arm64' && name.contains('arm64')) {
          match = a as Map<String, dynamic>;
          break;
        }
        if (arch == 'x86_64' && (name.contains('x86_64') || name.contains('x86'))) {
          match = a as Map<String, dynamic>;
          break;
        }
      }
      // Fall back to universal if no arch-specific asset matched.
      if (match == null) {
        for (final a in assets) {
          final name = (a as Map<String, dynamic>)['name'] as String? ?? '';
          if (name.toLowerCase().contains('universal') && name.toLowerCase().endsWith('.apk')) {
            match = a as Map<String, dynamic>;
            break;
          }
        }
      }
      // Last resort: any apk.
      if (match == null) {
        for (final a in assets) {
          final name = (a as Map<String, dynamic>)['name'] as String? ?? '';
          if (name.toLowerCase().endsWith('.apk')) {
            match = a as Map<String, dynamic>;
            break;
          }
        }
      }
      if (match == null) return null;
      final url = match['browser_download_url'] as String?;
      if (url == null || url.isEmpty) return null;
      return AppUpdateInfo(version: tag, apkUrl: url);
    } catch (e) {
      if (kDebugMode) debugPrint('AppUpdate check failed: $e');
      return null;
    }
  }

  static String _deviceArch() {
    // Android reports abi via dart:io Platform (no plugin needed).
    if (Platform.isAndroid) {
      // Runtime arch hint from the process; best-effort.
      final abi = Platform.operatingSystemVersion.toLowerCase();
      if (abi.contains('aarch64') || abi.contains('arm64')) return 'arm64';
      if (abi.contains('x86_64')) return 'x86_64';
    }
    // Default for desktop/dev builds.
    return 'universal';
  }

  /// Simple numeric-ish compare: strips non-digits/dots and compares each
  /// dotted segment. Returns true when [candidate] is greater than [current].
  static bool _isNewer(String candidate, String current) {
    final c = _segments(candidate);
    final o = _segments(current);
    final n = c.length > o.length ? c.length : o.length;
    for (var i = 0; i < n; i++) {
      final cv = i < c.length ? c[i] : 0;
      final ov = i < o.length ? o[i] : 0;
      if (cv != ov) return cv > ov;
    }
    return false;
  }

  static List<int> _segments(String v) {
    final cleaned = v.replaceAll(RegExp(r'[^0-9.]'), '');
    return cleaned.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  }
}

/// Riverpod provider exposing the update check result. Cached for the app
/// lifetime; re-checked only on first read.
final appUpdateProvider = FutureProvider<AppUpdateInfo?>((ref) async {
  return AppUpdateService.checkForUpdate();
});