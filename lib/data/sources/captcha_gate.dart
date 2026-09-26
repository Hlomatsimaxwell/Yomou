/// Cloudflare "Just a moment..." handling.
///
/// Some sources sit behind a Cloudflare interstitial: plain HTTP requests are
/// answered with a challenge page instead of content, and no amount of
/// header tuning gets past it — the challenge has to be solved in a real
/// browser engine once. When that happens the browser drops a clearance
/// cookie which plain requests can then replay, so the flow is:
///
/// 1. a request comes back as a challenge (detected by [isCloudflareChallenge]),
/// 2. the source throws [CaptchaRequiredException],
/// 3. the UI offers a "Solve" button that opens [CaptchaSolverScreen],
/// 4. the earned cookie is stored per source and replayed by [DioSource].
library;

import 'package:yomou/core/diagnostics/diag_log.dart';

/// Thrown when a source answered with a challenge page instead of content.
class CaptchaRequiredException implements Exception {
  const CaptchaRequiredException({
    required this.sourceId,
    required this.challengeUrl,
  });

  /// Source that needs the solve, used to store and replay the cookie.
  final String sourceId;

  /// Page the user has to open to clear the challenge.
  final String challengeUrl;

  @override
  String toString() => 'CaptchaRequiredException($sourceId)';
}

/// Whether [body] is a Cloudflare interstitial rather than real content.
///
/// Detection is deliberately signature-based: `cf-mitigated: challenge` is
/// authoritative, and the body check requires the challenge script host plus
/// one of the challenge markers, so ordinary pages are never mistaken for one.
bool isCloudflareChallenge({
  required int status,
  Map<String, List<String>>? headers,
  required String body,
}) {
  final mitigated = (headers?[CfHeaders.mitigated] ?? const <String>[])
      .join(',')
      .toLowerCase();
  if (mitigated.contains('challenge')) {
    diagSoon('cf-check status=$status mitigated=$mitigated len=${body.length}');
    return true;
  }

  if (body.length > 200_000) {
    diagSoon('cf-check status=$status oversized=${body.length}');
    return false;
  }
  final b = body.toLowerCase();
  if (!b.contains('challenges.cloudflare.com')) return false;
  return b.contains('cf-chl') ||
      b.contains('cf_chl_opt') ||
      b.contains('just a moment') ||
      b.contains('checking your browser');
}

/// Cookie names Cloudflare uses to mark a cleared visitor. Seeing one of these
/// is necessary but not sufficient: the interstitial sets cookies of its own
/// before the challenge completes, so callers also confirm the page is no
/// longer the challenge.
const Set<String> kCloudflareClearanceCookies = {'cf_clearance', '__cf_bm'};

/// Header names Cloudflare adds to its responses.
abstract final class CfHeaders {
  static const String mitigated = 'cf-mitigated';
  static const String ray = 'cf-ray';
}
