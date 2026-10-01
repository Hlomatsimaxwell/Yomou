import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yomou/main.dart' show appNavigatorKey;
import 'captcha_gate.dart';
import 'source_network.dart';
import 'package:yomou/core/diagnostics/diag_log.dart';
import 'package:yomou/core/widgets/webview_support.dart';

/// One queued WebView operation. [priority] tasks are the ones a user is
/// waiting on (opening a source, viewing details, reading); everything else
/// queues behind them so background fan-outs can't stall the foreground.
class _Pending {
  _Pending(this.run, {required this.priority}) : queuedAt = DateTime.now();
  final Future<void> Function() run;
  final bool priority;

  /// When the task was queued, so queue-starvation time can be told apart
  /// from a slow page in the diagnostics.
  final DateTime queuedAt;
}

/// Fetches pages that only exist after JavaScript runs.
///
/// MangaFire (and other Cloudflare-fronted sites) serve an empty SPA shell to
/// plain HTTP clients and gate their JSON API behind a JavaScript challenge, so
/// a `Dio` request can never list their content. This renders the page in an
/// off-screen [InAppWebView] — the challenge solves itself because a real
/// browser engine executes it — then hands back the rendered DOM.
///
/// The clearance cookies the WebView earns are stored per source, so the
/// cheaper plain-HTTP path can keep working for the rest of the session.
class WebViewFetcher {
  WebViewFetcher._();
  static final WebViewFetcher instance = WebViewFetcher._();

  InAppWebViewController? _controller;
  OverlayEntry? _entry;
  Completer<String>? _pending;

  final List<_Pending> _queue = [];
  bool _draining = false;

  /// True while a queued task is inside the WebView, so the keep-alive ping
  /// never interleaves with a request's own polling.
  bool _busy = false;

  /// Keeps the hidden WebView's renderer warm. Android parks an off-screen,
  /// near-invisible WebView's renderer when it sits idle, and the first call
  /// after every idle stretch pays a long unfreeze (~15-44s on this device).
  /// A trivial evaluation every few seconds stops it parking.
  Timer? _keepAlive;

  /// Marks the current async call tree as background work, so its WebView
  /// requests queue behind anything the user is waiting on.
  ///
  /// A zone value rather than a static flag: several fan-outs run in parallel,
  /// and a shared flag would leak one batch's status onto a foreground request
  /// that happens to run at the same time.
  static const _backgroundKey = Symbol('yomou.webview.background');

  /// Runs [body] with its WebView requests queued as background-priority.
  static Future<T> runBackground<T>(Future<T> Function() body) =>
      runZoned(body, zoneValues: {_backgroundKey: true});

  static bool get _isBackground => Zone.current[_backgroundKey] == true;

  /// Queues [task], foreground tasks jumping over any queued background ones
  /// while keeping FIFO order among themselves.
  void _enqueue(_Pending task) {
    if (task.priority) {
      var i = 0;
      while (i < _queue.length && _queue[i].priority) {
        i++;
      }
      _queue.insert(i, task);
    } else {
      _queue.add(task);
    }
    unawaited(_drain());
  }

  /// Runs queued operations one at a time. A task enqueued while another is
  /// running is picked up by the loop, so a foreground request arriving mid-way
  /// through a background task only waits out that one page.
  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final task = _queue.removeAt(0);
        final waitMs = DateTime.now().difference(task.queuedAt).inMilliseconds;
        if (waitMs > 5000) {
          diagSoon(
            'webview: queue wait ${waitMs ~/ 1000}s '
            'pri=${task.priority ? 'high' : 'low'}',
          );
        }
        final t0 = DateTime.now();
        _busy = true;
        try {
          await task.run();
        } catch (_) {
          // _run/_runInPage report their own outcome into the completer; this
          // only keeps one failing task from stalling the queue.
        } finally {
          _busy = false;
        }
        final took = DateTime.now().difference(t0);
        if (took > const Duration(seconds: 8)) {
          diagSoon('webview: task took ${took.inSeconds}s');
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// The clearance cookie names Cloudflare sets, which are worth keeping.
  static const Set<String> _keepCookies = {
    'cf_clearance',
    'XSRF-TOKEN',
    'XSRF-TOKEN-ALT',
    'laravel_session',
    'mf_session',
  };

  /// Loads [url] in the hidden WebView and returns the rendered HTML.
  ///
  /// Requests are queued, so concurrent source calls do not fight over the
  /// single WebView. [priority] requests (a source page, details, the reader)
  /// jump any queued background fan-out requests. Throws on timeout so callers
  /// can fall back to plain HTTP.
  Future<String> render(
    String url, {
    required String sourceId,
    String? expected,
    Duration timeout = const Duration(seconds: 30),
    bool priority = false,
  }) {
    final completer = Completer<String>();
    _enqueue(
      _Pending(
        () => _run(url, sourceId, expected, timeout, completer),
        priority: priority || !_isBackground,
      ),
    );
    return completer.future;
  }

  /// Makes an API call from inside the page and returns the response text.
  ///
  /// This is the only way to talk to a JSON API that sits behind Cloudflare
  /// once the challenge has been solved. A valid `cf_clearance` cookie is not
  /// enough on its own: Cloudflare validates the client as well as the cookie,
  /// so a `Dio` request carrying a cookie earned by the WebView is challenged
  /// again. Letting the browser issue the request means the TLS/HTTP2
  /// fingerprint and the cookie jar are the ones that already passed.
  ///
  /// [js] runs in the page and is expected to assign its outcome to
  /// `window.__mbData` / `window.__mbStatus` / `window.__mbErr` and set
  /// `window.__mbDone` when finished. The result is then polled out.
  Future<String> callInPage(
    String url,
    String js, {
    required String sourceId,
    Duration cap = const Duration(seconds: 25),
    bool priority = false,
  }) {
    final completer = Completer<String>();
    _enqueue(
      _Pending(
        () => _runInPage(url, js, sourceId, cap, completer),
        priority: priority || !_isBackground,
      ),
    );
    return completer.future;
  }

  Future<void> _runInPage(
    String url,
    String js,
    String sourceId,
    Duration cap,
    Completer<String> completer,
  ) async {
    try {
      // While the challenge is up, every further call would wait out the same
      // timeout and fail the same way. Reporting it once lets the solver fix the
      // session, instead of paying the cost again for every caller in a queue.
      final challengedAt = _challengedAt;
      if (challengedAt != null) {
        // Only short-circuit the rest of an in-flight queue. Past that window
        // (or once a solve has run) the call must be allowed to try again, or a
        // single challenge would deadlock the source for the whole session.
        if (DateTime.now().difference(challengedAt) <
            const Duration(seconds: 45)) {
          throw CaptchaRequiredException(sourceId: sourceId, challengeUrl: url);
        }
        _challengedAt = null;
      }
      // The real browser identity is required: a spoofed user agent is
      // detectable and turns the challenge into an endless verify loop.
      await _ensureWebView(sourceId);
      final controller = _controller;
      if (controller == null) throw StateError('no webview');

      final target = Uri.parse(url);
      if (_currentOrigin != target.origin) {
        await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
        _currentOrigin = target.origin;
        await _settledHtml(controller, cap: const Duration(seconds: 12));
      }

      // An API call is only worth making from a real, loaded document: the
      // interstitial cannot answer one.
      if (!await _pageReady(controller)) {
        // Clearance expires while the app sits idle, so the page it comes back
        // to can be the challenge again. One reload gives the browser a chance
        // to solve it unattended; if it does not, this is a real captcha and the
        // solver takes over rather than every queued call timing out.
        await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
        _currentOrigin = target.origin;
        if (!await _pageReady(controller)) {
          _challengedAt = DateTime.now();
          throw CaptchaRequiredException(sourceId: sourceId, challengeUrl: url);
        }
      }

      final injected = '${await controller.evaluateJavascript(
        source:
            'window.__mbDone=false;window.__mbData="";'
            'window.__mbStatus=0;window.__mbErr="";\n$js',
      )}';
      // The script is expected to return 'started'. Anything else means it
      // never ran - a syntax error, or a navigation replaced the context - and
      // the poll below would then sit out the whole cap for no visible reason.
      if (!injected.contains('started')) {
        diagSoon('$sourceId in-page script did not start (got $injected)');
      }

      final deadline = DateTime.now().add(cap);
      while (DateTime.now().isBefore(deadline)) {
        final done = await controller.evaluateJavascript(
          source: 'String(window.__mbDone)',
        );
        if ('$done' == 'true') {
          final status = await controller.evaluateJavascript(
            source: 'String(window.__mbStatus)',
          );
          final data = await controller.evaluateJavascript(
            source: 'window.__mbData || ""',
          );
          final err = await controller.evaluateJavascript(
            source: 'window.__mbErr || ""',
          );
          final text = _decodeJsString(data);
          // Only an unexpected answer is worth a body sample; a healthy one
          // would otherwise bury the rest of the log.
          if (status != '200' || !text.trimLeft().startsWith('{')) {
            final head = text.length > 90
                ? '${text.substring(0, 90)}...'
                : text;
            diagSoon(
              '$sourceId in-page status=$status len=${text.length} '
              'head=${head.replaceAll(RegExp(r'\s+'), ' ')}',
            );
          }
          if (text.isNotEmpty) {
            _challengedAt = null;
            if (!completer.isCompleted) completer.complete(text);
            return;
          }
          final failure =
              'in-page call failed: status=$status err=${_decodeJsString(err)}';
          diagSoon('$sourceId $failure');
          if (!completer.isCompleted) {
            completer.completeError(StateError(failure));
          }
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      if (!completer.isCompleted) {
        // Say what the page looked like when the wait ran out: a request that
        // never settles and a page that navigated away look identical from here.
        var where = 'unreadable';
        var err = '';
        try {
          where = '${await controller.evaluateJavascript(
            source: 'String(document.title)'
                ' + " ready=" + String(document.readyState)'
                ' + " url=" + String(window.location ? window.location.href : "")',
          )}';
          err = _decodeJsString(
            await controller.evaluateJavascript(source: 'window.__mbErr || ""'),
          );
        } catch (_) {
          // Diagnostics only.
        }
        diagSoon(
          '$sourceId in-page never finished in ${cap.inSeconds}s '
          'err=$err page=$where',
        );
        completer.completeError(TimeoutException('in-page call timed out'));
      }
    } catch (e) {
      diagSoon('$sourceId in-page call threw: $e');
      if (!completer.isCompleted) completer.completeError(e);
    }
  }

  /// Whether the WebView is sitting on a real, settled document that can serve
  /// an API call, or on the challenge / a still-empty page.
  ///
  /// The document merely has to be loaded. Whether a request needs a CSRF token
  /// is the request's business, not the page's: the site does not put the token
  /// in a meta tag on every page, and insisting on one here made a perfectly
  /// good page look unready forever and raised a captcha that did not exist.
  ///
  /// Every verdict is logged with the title and body length it was based on.
  /// This is the check that decides whether the user is shown a captcha banner,
  /// and a check that can silently fail leaves no way to tell a real challenge
  /// apart from a page that simply had not finished rendering.
  Future<bool> _pageReady(
    InAppWebViewController controller, {
    Duration cap = const Duration(seconds: 6),
  }) async {
    final deadline = DateTime.now().add(cap);
    var polls = 0;
    String? lastVerdict;
    while (DateTime.now().isBefore(deadline)) {
      final String state;
      try {
        state = '${await controller.evaluateJavascript(
          source: 'String((function () {'
            ' var t = (document.title || "");'
            ' var l = t.toLowerCase();'
            ' var s;'
            ' if (l.indexOf("just a moment") >= 0 ||'
            '     l.indexOf("attention required") >= 0 ||'
            '     l.indexOf("checking your browser") >= 0) s = "challenged";'
            ' else if (document.querySelector("#challenge-form") ||'
            '     document.querySelector("#challenge-running") ||'
            '     document.querySelector("#challenge-stage") ||'
            '     document.querySelector(\'iframe[src*="challenges.cloudflare.com"]\'))'
            '   s = "challenged";'
            // A document with a body that is not still the blank pre-load shell.
            ' else if (!document.body || document.body.innerHTML.length < 200)'
            '   s = "empty";'
            ' else s = "ready";'
            ' return s + "|" +'
            '   (document.body ? document.body.innerHTML.length : -1) + "|" + t;'
            ' })())',
        )}';
      } catch (_) {
        // Still loading: the platform view cannot run script yet.
        await Future<void>.delayed(const Duration(milliseconds: 350));
        continue;
      }
      polls++;
      // The title can contain the separator, so only the first two fields are
      // structural and the rest is the title.
      final bits = state.split('|');
      final verdict = bits.isEmpty ? 'unknown' : bits.first;
      final bodyLen = bits.length > 1 ? bits[1] : '?';
      final title = bits.length > 2 ? bits.sublist(2).join('|') : '';
      if (verdict != lastVerdict) {
        lastVerdict = verdict;
        diagSoon('pageReady -> $verdict bodyLen=$bodyLen title="$title"');
      }
      if (verdict == 'ready') return true;
      if (verdict == 'challenged') {
        // Nothing is going to change while the challenge is on screen, so there
        // is no reason to spend the rest of the budget waiting.
        diagSoon('pageReady challenged title="$title" after ${polls}polls');
        _challengedAt = DateTime.now();
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    diagSoon(
      'pageReady timed out verdict=${lastVerdict ?? "none"} '
      'polls=$polls cap=${cap.inSeconds}s',
    );
    return false;
  }

  /// When the challenge was last seen, so a queue of callers does not each wait
  /// for the same page to change.
  DateTime? _challengedAt;

  /// Clears the "known challenged" latch. The solver screen runs a real browser
  /// against the same cookie jar, so once it reports a solve the next call has to
  /// be allowed to attempt the request again.
  void clearChallengeLatch() {
    _challengedAt = null;
  }

  /// Where the hidden WebView currently sits, so same-origin calls can skip a
  /// reload.
  String? _currentOrigin;

  /// Writes every rendered page to the app's external files directory, so the
  /// real markup of a JavaScript-gated site can be inspected while its parser
  /// is being written. Enabled by default during bring-up; turn off once a
  /// source parses correctly.
  static bool dumpEnabled = true;

  Future<void> _dump(String sourceId, String html) async {
    if (!dumpEnabled || html.isEmpty) return;
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final target = Directory('${dir.path}/webview_dump');
      if (!await target.exists()) await target.create(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await File('${target.path}/${sourceId}_$stamp.html').writeAsString(html);
    } catch (_) {
      // Diagnostics only.
    }
  }

  Future<void> _run(
    String url,
    String sourceId,
    String? expected,
    Duration timeout,
    Completer<String> completer,
  ) async {
    if (_pending != null) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('WebView busy'));
      }
      return;
    }
    _pending = completer;
    try {
      await _ensureWebView(sourceId);
      final controller = _controller;
      if (controller == null) {
        throw StateError('no webview');
      }
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      _currentOrigin = Uri.parse(url).origin;
      final html = await _settledHtml(controller, expected: expected);
      await _dump(sourceId, html);
      // A challenge page settles just as quickly as a real one and is small but
      // over the size floor below, so without this it was handed back as
      // content: the caller parsed an empty grid out of an interstitial and
      // reported "no results", with no captcha banner anywhere to say why.
      if (isCloudflareChallenge(status: 0, body: html)) {
        _challengedAt = DateTime.now();
        diagSoon('$sourceId render: $url is a challenge, not content');
        throw CaptchaRequiredException(sourceId: sourceId, challengeUrl: url);
      }
      if (expected != null && !html.contains(expected)) {
        diagSoon('$sourceId render: $url never showed "$expected"');
      }
      if (!completer.isCompleted) completer.complete(html);
    } catch (e) {
      diagSoon('$sourceId render failed for $url: $e');
      if (!completer.isCompleted) completer.completeError(e);
    } finally {
      _pending = null;
      unawaited(_captureCookies(url, sourceId));
    }
  }

  /// Polls the page until its content stops changing, so a half-rendered
  /// listing (skeleton placeholders still on screen) is never handed back.
  ///
  /// [expected] is a selector whose presence means the page is done, e.g.
  /// `a[href^="/title/"]`; when given, the wait ends as soon as it matches.
  ///
  /// Without [expected] there is nothing to wait *for*, only something to stop
  /// waiting for, and that decision needs a second signal. A still-changing
  /// document is obvious, but a document that is holding perfectly still is
  /// also what a page looks like while its script bundle is still downloading:
  /// the markup is already in place and nothing mutates until the script runs.
  /// MangaFire's grid is painted that way, over a mobile connection slow enough
  /// that its module script had not arrived after a second and a half, so the
  /// read gave up and handed back the empty `#app-root` shell - a finished
  /// verdict about a page that had not started. `readyState` separates the two:
  /// it only reads `complete` once every script and stylesheet has loaded.
  Future<String> _settledHtml(
    InAppWebViewController controller, {
    String? expected,
    Duration cap = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(cap);
    var last = '';
    var stable = 0;
    while (DateTime.now().isBefore(deadline)) {
      // readyState and the markup are read together so a poll stays one round
      // trip. The separator is a NUL, which an HTML parser replaces with U+FFFD
      // and so cannot occur in the markup itself.
      final raw = await controller.evaluateJavascript(
        source: 'document.readyState + String.fromCharCode(0)'
            ' + document.documentElement.outerHTML',
      );
      final read = _decodeJsString(raw);
      final split = read.indexOf('\u0000');
      final complete = split > 0 && read.substring(0, split) == 'complete';
      final html = split > 0 ? read.substring(split + 1) : read;
      if (expected != null && html.contains(expected)) {
        if (html != last) {
          last = html;
          stable = 0;
          await Future<void>.delayed(const Duration(milliseconds: 400));
          continue;
        }
        return html;
      }
      if (html == last) {
        stable++;
        // Two identical reads in a row on a fully loaded page: it has stopped
        // rendering. A page that is still empty is not finished, though: these
        // sites paint their body from a script, so an early pair of identical
        // reads would hand back a blank document.
        if (stable >= 2 && complete && html.length > 1500) return html;
      } else {
        stable = 0;
        last = html;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return last;
  }

  /// The WebView is kept alive between requests: solving the challenge once is
  /// the expensive part.
  ///
  /// Its user agent is left at the platform default on purpose. Cloudflare
  /// compares the identity the page presents with the one its clearance was
  /// issued to, and this WebView is shared by every source, so any spoofed
  /// value would contradict the session that actually solved the challenge.
  Future<void> _ensureWebView(String sourceId) async {
    if (_controller != null) return;
    // Refused before the overlay entry exists, because the failure of an
    // InAppWebView is not a throw the caller can catch: the widget asserts in
    // its constructor, which happens when the overlay is next built, after
    // this method has already returned. The assert then paints a full-screen
    // red error widget in the app's overlay while the caller carries on
    // waiting for a controller that can never arrive. Saying no here keeps
    // the failure on the path the sources already handle - they fall back to
    // their plain-HTTP path - instead of leaving a red screen behind.
    if (!inAppWebViewAvailable) {
      throw UnsupportedError(
        'no embedded browser on this platform: $sourceId cannot be fetched '
        'through a WebView',
      );
    }
    final navigator = appNavigatorKey.currentState;
    final overlay = navigator?.overlay;
    if (overlay == null) {
      diagSoon('$sourceId: no overlay for the hidden WebView '
          '(nav=${navigator == null ? "null" : "no overlay"})');
      throw StateError('no overlay');
    }

    final ready = Completer<InAppWebViewController>();
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        // Parked off-screen: the platform view must stay laid out and running,
        // it just must not be seen.
        left: -600,
        top: -1200,
        width: 420,
        height: 900,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.01,
            child: Material(
              child: InAppWebView(
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  thirdPartyCookiesEnabled: true,
                  transparentBackground: true,
                  userAgent: null,
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                  _startKeepAlive();
                  if (!ready.isCompleted) ready.complete(controller);
                },
              ),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    // Keep the entry mounted; it is only ever visible off-screen.
    await ready.future.timeout(const Duration(seconds: 15));
  }

  /// Stores the cookies the challenge earned, so plain requests inherit them.
  Future<void> _captureCookies(String url, String sourceId) async {
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(url),
      );
      final parts = <String>[];
      for (final c in cookies) {
        if (!_keepCookies.contains(c.name)) continue;
        parts.add('${c.name}=${c.value}');
      }
      if (parts.isEmpty) return;
      final header = parts.join('; ');
      final existing = await SourceNetworkConfig.forSource(sourceId);
      if (existing.cookies == header) return;
      await SourceNetworkConfig.setCookies(sourceId, value: header);
    } catch (_) {
      // Cookies are a bonus, not a requirement: the rendered HTML is the point.
    }
  }

  /// `evaluateJavascript` returns a JSON-encoded value on Android, so a string
  /// result arrives quoted and escaped.
  static String _decodeJsString(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final decoded = jsonDecode(raw);
      return decoded is String ? decoded : raw;
    } catch (_) {
      return raw;
    }
  }

  /// Releases the hidden WebView (used on sign-out and in tests).
  void dispose() {
    _keepAlive?.cancel();
    _keepAlive = null;
    _entry?.remove();
    _entry = null;
    _controller = null;
  }

  /// Starts (or restarts) the periodic ping that stops the renderer parking.
  void _startKeepAlive() {
    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_ping()),
    );
  }

  /// A trivial main-frame evaluation: cheap, and exactly the kind of touch
  /// that keeps the renderer from going to sleep. Skipped while a request is
  /// actually using the view.
  Future<void> _ping() async {
    final c = _controller;
    if (c == null || _busy) return;
    try {
      await c.evaluateJavascript(source: '1');
    } catch (_) {
      // The renderer may be mid-navigation or gone; a real call recreates it.
    }
  }
}
