import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/utils/concurrent.dart';

void main() {
  group('waitFastest', () {
    test('returns what completed inside the window, drops stragglers', () async {
      final slow = Completer<String>();
      final result = await waitFastest<String>(
        [Future.value('fast'), slow.future],
        deadline: const Duration(milliseconds: 50),
      );
      expect(result, ['fast']);
    });

    test('does not cancel the futures it gave up on', () async {
      // This is what makes the grace window free: the abandoned futures are
      // still running and a later pass can still collect them.
      final slow = Completer<String>();
      final first = waitFastest<String>(
        [slow.future],
        deadline: const Duration(milliseconds: 50),
      );
      expect(await first, isEmpty);

      slow.complete('late');
      final second = await waitFastest<String>(
        [slow.future],
        deadline: const Duration(milliseconds: 50),
      );
      expect(second, ['late']);
    });

    test('a future that throws counts as finished, not as a result', () async {
      final result = await waitFastest<String>(
        [Future<String>.error('boom'), Future.value('ok')],
        deadline: const Duration(seconds: 5),
      );
      expect(result, ['ok']);
    });
  });

  group('waitFastest grace', () {
    test('adds no latency when the first pass already has a result', () async {
      final sw = Stopwatch()..start();
      final result = await waitFastest<String>(
        [Future.value('fast')],
        deadline: const Duration(milliseconds: 40),
        grace: const Duration(seconds: 5),
      );
      sw.stop();

      expect(result, ['fast']);
      // Would be ~5s if it had waited out the grace window.
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 500)));
    });

    test('escalates past the first window and collects the stragglers', () async {
      var requests = 0;
      final a = Completer<String>();
      final b = Completer<String>();
      final futures = [
        () {
          requests++;
          return a.future;
        }(),
        () {
          requests++;
          return b.future;
        }(),
      ];

      final pending = waitFastest(
        futures,
        deadline: const Duration(milliseconds: 60),
        grace: const Duration(milliseconds: 600),
      );

      // Lands after the first window closed, inside the grace window.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      a.complete('late-a');
      b.complete('late-b');

      expect(await pending, ['late-a', 'late-b']);
      expect(requests, 2, reason: 'grace must not issue a second request');
    });

    test('treats a completed-but-empty pass as no result and escalates',
        () async {
      // Both error-ish sources resolve empty *inside* the first window, so the
      // first pass looks like progress by the "a future finished" measure. If
      // that counted as a result the fan-out would stop here and abandon the
      // straggler, which is the case this all guards.
      final emptyA = Future<String>.value('');
      final emptyB = Future<String>.value('');
      final straggler = Completer<String>();

      final pending = waitFastest(
        [emptyA, emptyB, straggler.future],
        deadline: const Duration(milliseconds: 200),
        grace: const Duration(milliseconds: 800),
        hasResult: (results) => results.any((r) => r.isNotEmpty),
      );

      await Future<void>.delayed(const Duration(milliseconds: 350));
      straggler.complete('late');

      // The straggler is only reachable if the two empties did not count as a
      // result, so finding it here is the escalation being observed.
      expect(await pending, ['', '', 'late']);
    });

    test('stops escalating after the grace window, even if still empty',
        () async {
      final emptyA = Future<String>.value('');
      final emptyB = Future<String>.value('');

      final sw = Stopwatch()..start();
      final result = await waitFastest(
        [emptyA, emptyB],
        deadline: const Duration(milliseconds: 50),
        grace: const Duration(milliseconds: 200),
        hasResult: (results) => results.any((r) => r.isNotEmpty),
      );
      sw.stop();

      // Every value that settled is still returned; hasResult only decides
      // whether to keep waiting, it never filters the results away.
      expect(result, ['', '']);
      // Exactly one grace window, not an unbounded retry loop.
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('honours hasResult over the default non-empty check', () async {
      final empty = Future<String>.value('');

      // Default: a completed-but-empty result counts as progress, so it does
      // not escalate and the straggler is left behind.
      final viaDefault = await waitFastest(
        [empty],
        deadline: const Duration(milliseconds: 40),
        grace: const Duration(milliseconds: 400),
      );
      expect(viaDefault, ['']);

      // With hasResult, the same pass counts as failure, so a value landing
      // inside the grace window is collected instead of abandoned.
      final straggler = Completer<String>();
      final pending = waitFastest(
        [empty, straggler.future],
        deadline: const Duration(milliseconds: 40),
        grace: const Duration(milliseconds: 600),
        hasResult: (results) => results.any((r) => r.isNotEmpty),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      straggler.complete('late');
      expect(await pending, ['', 'late']);
    });

    test('grace of zero is exactly the old behaviour', () async {
      final pending = Completer<String>();
      final result = await waitFastest<String>(
        [pending.future],
        deadline: const Duration(milliseconds: 50),
      );
      expect(result, isEmpty);
    });
  });

  group('waitFastest early resolve', () {
    test('resolves before the deadline once earlyResolve is satisfied',
        () async {
      // The straggler would make this wait out the whole window if the
      // settled-alone results did not count. The feed's core problem: fast
      // plain-HTTP sources answer in ~2s while everything else queues behind
      // the single WebView, and the old code held the feed hostage to the
      // window even though it already had plenty to show.
      final straggler = Completer<String>();
      final sw = Stopwatch()..start();
      final result = await waitFastest<String>(
        [Future.value('a'), Future.value('b'), straggler.future],
        deadline: const Duration(seconds: 5),
        earlyResolve: (results) => results.length >= 2,
      );
      sw.stop();

      expect(result, ['a', 'b']);
      expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('without earlyResolve the window is still honoured', () async {
      final straggler = Completer<String>();
      final sw = Stopwatch()..start();
      final result = await waitFastest<String>(
        [Future.value('a'), Future.value('b'), straggler.future],
        deadline: const Duration(milliseconds: 250),
      );
      sw.stop();

      // Search relies on this: it wants every source, so a fast pair must not
      // short-circuit the rest.
      expect(result, ['a', 'b']);
      expect(sw.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 200)));
    });

    test('earlyResolve defaults to hasResult for callers that pass it',
        () async {
      // _fanout passes hasResult everywhere; earlyResolve should not need to
      // be threaded through separately when the caller already told the
      // fan-out what "a result" means.
      final straggler = Completer<String>();
      final sw = Stopwatch()..start();
      final result = await waitFastest<String>(
        [Future.value('hit'), straggler.future],
        deadline: const Duration(seconds: 5),
        hasResult: (r) => r.any((v) => v == 'hit'),
      );
      sw.stop();

      expect(result, ['hit']);
      expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('an early empty pass still escalates into grace', () async {
      // Two empty-looking results landing quickly are not "a result" for a
      // fan-out that asked for non-empty content: early resolution must not
      // turn a fast-but-empty first pass into a *final* feed.
      final straggler = Completer<String>();
      final pending = waitFastest(
        [Future<String>.value(''), Future<String>.value(''), straggler.future],
        deadline: const Duration(milliseconds: 60),
        grace: const Duration(milliseconds: 400),
        hasResult: (results) => results.any((r) => r.isNotEmpty),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      straggler.complete('late');

      expect(await pending, ['', '', 'late']);
    });
  });
}
