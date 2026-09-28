import 'dart:async';

/// Runs [futures] concurrently and resolves once they all finish or the
/// [deadline] elapses, whichever comes first. Results only include the futures
/// that completed within the window, so one slow (or hanging) call can never
/// stall multi-source fan-out — whatever responded in time is returned and the
/// stragglers become a disk-cache hit on the next run.
///
/// A short window bounds the wait but it cannot distinguish "nothing is coming"
/// from "nothing has arrived *yet*". On a cold cache the first responses often
/// land seconds after the window closes, so a caller that gives up at [deadline]
/// settles on an empty result while the work it started is still in flight and
/// seconds from being useful. Passing a non-zero [grace] closes that gap: if
/// the first pass satisfied [hasResult] the result is returned immediately and
/// nothing is added to the common path, and otherwise the *same* futures are
/// given a further [grace] window. Re-waiting is free — these are futures that
/// are already running, not a second request — so the only cost of a grace
/// period is waiting when the first pass genuinely had nothing.
///
/// [hasResult] judges the first pass as a whole, which lets a caller treat a
/// completed-but-empty result as a failure and keep escalating. That matters
/// because a call which throws resolves to an empty value rather than hanging:
/// a pass where every source errored straight away otherwise looks like
/// progress and would stop after one window. Defaults to "the pass produced at
/// least one result".
Future<List<T>> waitFastest<T>(
  List<Future<T>> futures, {
  Duration deadline = const Duration(seconds: 6),
  Duration grace = Duration.zero,
  bool Function(List<T> results)? hasResult,
}) async {
  final first = await _collect(futures, deadline);
  if (grace <= Duration.zero) return first;
  if ((hasResult ?? (results) => results.isNotEmpty).call(first)) return first;
  return _collect(futures, grace);
}

Future<List<T>> _collect<T>(List<Future<T>> futures, Duration window) async {
  if (futures.isEmpty) return const [];
  final results = List<T?>.filled(futures.length, null);
  // "settled" and "produced a value" are separate: a future that throws
  // settles but contributes nothing. Collapsing the two left `results[i]` null
  // while still being collected, and casting that null to a non-nullable T
  // threw. Callers here wrap their sources in try/catch so a rejection is
  // rare, which is why it stayed latent rather than absent.
  final hasValue = List<bool>.filled(futures.length, false);
  final settled = List<bool>.filled(futures.length, false);
  var done = 0;
  final allDone = Completer<void>();
  for (var i = 0; i < futures.length; i++) {
    futures[i]
        .then((value) {
          results[i] = value;
          hasValue[i] = true;
          if (!settled[i]) {
            settled[i] = true;
            done++;
          }
          if (done == futures.length && !allDone.isCompleted) {
            allDone.complete();
          }
        })
        .catchError((_) {
          if (!settled[i]) {
            settled[i] = true;
            done++;
          }
          if (done == futures.length && !allDone.isCompleted) {
            allDone.complete();
          }
        });
  }
  await allDone.future.timeout(window, onTimeout: () {});
  return [
    for (var i = 0; i < futures.length; i++)
      if (hasValue[i]) results[i] as T,
  ];
}
