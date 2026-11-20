import 'dart:async';

/// Counting semaphore: at most [limit] holders at a time.
///
/// A released slot is handed straight to the first waiter instead of
/// decrementing the count and letting waiters race for it, so the number of
/// holders can never exceed [limit].
class TaskSlots {
  TaskSlots(int limit) : _limit = limit < 1 ? 1 : limit;

  int _limit;
  int _active = 0;
  final List<Completer<void>> _waiters = [];

  /// Maximum simultaneous holders. May change at any time; a smaller limit
  /// takes effect as the extra holders release.
  int get limit => _limit;
  set limit(int value) => _limit = value < 1 ? 1 : value;

  /// Holders currently inside [acquire]/[release] or [run].
  int get active => _active;

  Future<void> acquire() async {
    if (_active < _limit) {
      _active++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
      return;
    }
    if (_active > 0) _active--;
  }

  /// Runs [action] while holding a slot, releasing it even when [action]
  /// throws.
  Future<T> run<T>(Future<T> Function() action) async {
    await acquire();
    try {
      return await action();
    } finally {
      release();
    }
  }
}
