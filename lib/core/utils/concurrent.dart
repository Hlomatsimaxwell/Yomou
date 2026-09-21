import 'dart:async';

/// Runs [futures] concurrently and resolves once they all finish or the
/// [deadline] elapses, whichever comes first. Results only include the futures
/// that completed within the window, so one slow (or hanging) call can never
/// stall multi-source fan-out — whatever responded in time is returned and the
/// stragglers become a disk-cache hit on the next run.
Future<List<T>> waitFastest<T>(
  List<Future<T>> futures, {
  Duration deadline = const Duration(seconds: 6),
}) async {
  if (futures.isEmpty) return const [];
  final results = List<T?>.filled(futures.length, null);
  final completed = List<bool>.filled(futures.length, false);
  var done = 0;
  final allDone = Completer<void>();
  for (var i = 0; i < futures.length; i++) {
    futures[i]
        .then((value) {
          if (!completed[i]) {
            completed[i] = true;
            done++;
          }
          results[i] = value;
          if (done == futures.length && !allDone.isCompleted) {
            allDone.complete();
          }
        })
        .catchError((_) {
          if (!completed[i]) {
            completed[i] = true;
            done++;
          }
          if (done == futures.length && !allDone.isCompleted) {
            allDone.complete();
          }
        });
  }
  await allDone.future.timeout(deadline, onTimeout: () {});
  return [
    for (var i = 0; i < futures.length; i++)
      if (completed[i]) results[i] as T,
  ];
}