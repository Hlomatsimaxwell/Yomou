import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';

/// Emits a tick on a user-configurable cadence (see Settings > Storage and
/// network > suggestions refresh rate). Providers that watch this recompute on
/// each tick, so the Explore featured carousel and the suggestions feed get a
/// fresh rotation without the user having to pull-to-refresh. Changing the
/// interval restarts the stream with the new period.
final periodicSuggestionsRefreshProvider =
    StreamProvider.autoDispose<int>((ref) {
  final minutes = ref.watch(suggestionsRefreshMinutesProvider);
  final interval = Duration(minutes: minutes);
  return Stream<int>.periodic(interval, (i) => i + 1);
});