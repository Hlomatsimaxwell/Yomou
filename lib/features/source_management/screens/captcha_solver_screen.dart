import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/sources/captcha_gate.dart';
import '../../../data/sources/source_network.dart';
import '../../../data/sources/webview_fetcher.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'package:yomou/core/diagnostics/diag_log.dart';

/// A visible browser the user clears a Cloudflare challenge in.
///
/// The interstitial cannot be solved programmatically, so the user does it by
/// hand once. The clearance cookie is then stored per source and replayed by
/// every later request, which is why the WebView has to impersonate the same
/// browser the HTTP client claims to be: `_cf_clearance` is bound to the user
/// agent, and a mismatch makes the cookie worthless.
///
/// This screen never closes itself. Whether a challenge is on screen is
/// reported in a status strip instead of being decided here, and only
/// Continue ends the session — a screen that dismisses itself on a page it
/// never finished loading is worse than one that waits, because it reports a
/// solve that did not happen.
class CaptchaSolverScreen extends StatefulWidget {
  const CaptchaSolverScreen({
    super.key,
    required this.sourceId,
    required this.url,
    required this.userAgent,
  });

  final String sourceId;
  final String url;

  /// Must match the user agent the source's HTTP client sends.
  final String userAgent;

  @override
  State<CaptchaSolverScreen> createState() => _CaptchaSolverScreenState();
}

class _CaptchaSolverScreenState extends State<CaptchaSolverScreen> {
  InAppWebViewController? _controller;
  WebUri? _currentUri;
  Timer? _poll;
  bool _saving = false;
  int _progress = 0;
  String? _lastCookieSig;

  /// Changes to any of these are worth a log line, so the readout on screen and
  /// the diagnostics agree on what the browser is doing.
  String? _lastProbeSig;

  String? _webViewUserAgent;

  /// Plain-language state of the embedded browser, shown on screen.
  ///
  /// The interstitial renders inside a WebView the user cannot always read, so
  /// without this the screen either closes itself on a page that was never
  /// solved or leaves the user guessing whether a challenge is even present.
  String _pageTitle = '(not loaded)';
  String _pageUrl = '(none)';
  String _challengeState = 'unknown';
  String _cookieState = 'none';
  bool _bodyEmpty = true;
  int _bodyLen = -1;

  /// Whether a challenge is on screen right now, kept beside [_challengeState]
  /// so the strip can colour itself without matching on wording.
  bool _challengeOnScreen = false;

  /// Everything the status strip reports, gathered in a single round trip so
  /// the numbers on screen and the log line cannot disagree.
  ///
  /// `evaluateJavascript` hands back a JSON-encoded value, so this returns a
  /// JSON *string* which arrives double-quoted and escaped; [_readPage] peels
  /// off both layers.
  static const String _probeScript = r'''
(function () {
  var title = document.title || '';
  var lower = title.toLowerCase();
  var challenge =
      lower.indexOf('just a moment') >= 0 ||
      lower.indexOf('attention required') >= 0 ||
      lower.indexOf('checking your browser') >= 0;
  if (!challenge) {
    challenge = !!(
      document.querySelector('#challenge-form') ||
      document.querySelector('#challenge-running') ||
      document.querySelector('#challenge-stage') ||
      document.querySelector('iframe[src*="challenges.cloudflare.com"]')
    );
  }
  return JSON.stringify({
    title: title,
    url: (window.location ? window.location.href : ''),
    challenge: challenge,
    bodyLen: document.body ? document.body.innerHTML.length : -1,
    readyState: document.readyState || '?'
  });
})()
''';

  /// A body shorter than this is the blank pre-load shell rather than a page.
  static const int _minBodyLength = 200;

  @override
  void initState() {
    super.initState();
    diagSoon('solver open source=${widget.sourceId} url=${widget.url}');
    _poll = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => _probe(),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Samples the embedded browser and refreshes the status strip.
  ///
  /// Nothing here decides anything or closes the screen. The interstitial sets
  /// cookies of its own before the challenge finishes, and a page that has not
  /// loaded yet looks exactly like a page with no challenge on it, so any
  /// verdict taken from a single sample — in either direction — would be a
  /// guess. Reporting is the whole job; the user ends the session.
  Future<void> _probe() async {
    if (_saving || _controller == null) return;
    final uri = _currentUri;
    // No document yet: the strip keeps saying so, which is the honest answer.
    if (uri == null) return;

    final cookies = await CookieManager.instance().getCookies(
      url: WebUri(uri.toString()),
    );
    final names = cookies.map((c) => c.name).toSet();
    final sorted = (names.toList()..sort()).join(',');
    if (sorted != _lastCookieSig) {
      _lastCookieSig = sorted;
      diagSoon(
        'solver cookies=[$sorted] '
        'clearance=${names.any(kCloudflareClearanceCookies.contains)}',
      );
    }

    final page = await _readPage();
    if (!mounted) return;
    _publish(page, names);

    final sig = '$_pageTitle|$_pageUrl|$_challengeState|$_bodyLen|$sorted';
    if (sig != _lastProbeSig) {
      _lastProbeSig = sig;
      diagSoon(
        'solver probe title="$_pageTitle" url=$_pageUrl '
        'challenge=$_challengeState onScreen=$_challengeOnScreen '
        'bodyLen=$_bodyLen ready=${page['readyState']} cookies=[$sorted]',
      );
    }
  }

  /// Runs [_probeScript] and decodes the result.
  Future<Map<String, Object?>> _readPage() async {
    final controller = _controller;
    if (controller == null) return const {};
    final String raw;
    try {
      raw = '${await controller.evaluateJavascript(source: _probeScript)}';
    } catch (_) {
      // The platform view cannot run script yet; the next tick will try again.
      return const {};
    }
    Object? decoded = raw;
    try {
      decoded = jsonDecode(decoded as String);
    } catch (_) {
      // Not JSON at all; fall through and show the raw text as the title.
    }
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        // Leave it as a plain string.
      }
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
    return {'title': '$decoded'};
  }

  /// Pushes what the browser is showing into the status strip.
  void _publish(Map<String, Object?> page, Set<String> cookieNames) {
    if (!mounted || page.isEmpty) return;
    final title = '${page['title'] ?? ''}'.trim();
    final href = '${page['url'] ?? ''}'.trim();
    final challenge = page['challenge'] == true;
    final len = int.tryParse('${page['bodyLen']}') ?? -1;

    setState(() {
      _pageTitle = title.isEmpty ? '(untitled)' : title;
      _pageUrl = href.isEmpty ? '(unknown)' : href;
      _challengeOnScreen = challenge;
      _challengeState = challenge
          ? 'on screen'
          : '${page['readyState']}' == 'complete'
              ? 'none seen'
              : 'loading (${page['readyState']})';
      _bodyLen = len;
      _bodyEmpty = len < _minBodyLength;
      _cookieState = cookieNames.isEmpty
          ? 'none'
          : (cookieNames.toList()..sort()).join(', ') +
              (cookieNames.any(kCloudflareClearanceCookies.contains)
                  ? '  [clearance present]'
                  : '  [no clearance]');
    });
  }

  /// Remembers the browser's real user agent.
  ///
  /// `_cf_clearance` is bound to the user agent that earned it, and the HTTP
  /// client has to present the same one, so the solved UA is persisted next to
  /// the cookie and replayed from then on.
  Future<void> _captureUserAgent(InAppWebViewController controller) async {
    if (_webViewUserAgent != null) return;
    try {
      final ua = await controller.evaluateJavascript(
        source: 'navigator.userAgent',
      );
      final value = '${ua ?? ''}'.replaceAll('"', '').trim();
      if (value.isNotEmpty) _webViewUserAgent = value;
    } catch (_) {
      // Fall back to whatever the caller expected.
    }
  }

  /// Stores the cookies the browser ended up with, then closes.
  ///
  /// Only ever reached from Continue, so the stored session is always the one
  /// the user looked at and accepted.
  Future<void> _finish() async {
    if (_saving) return;
    diagSoon(
      'solver finish: ${widget.sourceId} '
      'challenge=$_challengeState bodyLen=$_bodyLen cookies=$_cookieState',
    );
    setState(() => _saving = true);
    _poll?.cancel();

    try {
      final list = await CookieManager.instance().getCookies(
        url: WebUri(widget.url),
      );
      // Store every cookie the browser ended up with, not just the Cloudflare
      // ones: `cf_clearance` gets us past the challenge, but the site also
      // needs its own session cookie for the CSRF-protected API to accept the
      // requests that follow.
      final keep = list
          .where((c) => c.name.isNotEmpty && c.value.isNotEmpty)
          .map((c) => '${c.name}=${c.value}')
          .join('; ');
      if (keep.isNotEmpty) {
        await SourceNetworkConfig.setCookies(widget.sourceId, value: keep);
      }
      final ua = _webViewUserAgent;
      if (ua != null && ua.isNotEmpty) {
        await SourceNetworkConfig.setUserAgent(widget.sourceId, value: ua);
      }
    } catch (e) {
      debugPrint('captcha: storing cookies failed: $e');
    }

    // The retry that follows needs to be allowed to reach the network again.
    WebViewFetcher.instance.clearChallengeLatch();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(_currentUri?.toString() ?? widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// One `label: value` line of the status strip.
  Widget _row(
    String label,
    String value, {
    Color? valueColor,
    String? sub,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: valueColor ?? theme.colorScheme.onSurface,
                    fontWeight: valueColor == null ? null : FontWeight.w600,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The always-visible readout of what the embedded browser is showing.
  ///
  /// Sits below the WebView rather than over it, so it can never hide the very
  /// challenge the user has been asked to solve.
  Widget _statusStrip(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final challengeText = switch (_challengeState) {
      'on screen' => l10n.captchaChallengeOnScreen,
      'none seen' => l10n.captchaChallengeNone,
      _ => l10n.captchaChallengeUnknown,
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _challengeOnScreen ? scheme.error : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _challengeOnScreen ? Icons.report : Icons.visibility,
                size: 14,
                color: _challengeOnScreen ? scheme.error : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.captchaStatusTitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _row(l10n.captchaStatusPage, _pageTitle, sub: _pageUrl),
          _row(
            l10n.captchaStatusChallenge,
            challengeText,
            valueColor: _challengeOnScreen ? scheme.error : null,
          ),
          _row(
            l10n.captchaStatusContent,
            _bodyEmpty ? l10n.captchaContentEmpty : l10n.captchaContentLoaded,
            sub: _bodyLen < 0 ? null : '$_bodyLen chars',
          ),
          _row(l10n.captchaStatusCookies, _cookieState),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.captchaSolveTitle),
        actions: [
          IconButton(
            tooltip: l10n.openInBrowser,
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
        bottom: _progress > 0 && _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
          // The UA is deliberately NOT spoofed here: Cloudflare compares
          // it against the real device fingerprint, and an Android WebView
          // claiming to be desktop Chrome just re-challenges forever.
        ),
        onWebViewCreated: (controller) => _controller = controller,
        onProgressChanged: (controller, progress) {
          if (mounted) setState(() => _progress = progress);
        },
        onUpdateVisitedHistory: (controller, url, isReload) {
          _currentUri = url;
          _probe();
        },
        onLoadStop: (controller, url) {
          _currentUri = url;
          _captureUserAgent(controller);
          _probe();
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statusStrip(l10n),
              Text(
                l10n.captchaSolveHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _finish,
                child: Text(l10n.captchaContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
