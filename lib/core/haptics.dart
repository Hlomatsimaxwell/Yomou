import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yomou/features/settings/providers/appearance_provider.dart';

/// How strong a piece of feedback is.
enum AppHaptic { selection, light, medium }

/// Fires a haptic tap, unless the reader has turned haptics off in Appearance.
///
/// Every call site goes through here rather than touching [HapticFeedback]
/// directly, so the setting is honoured in exactly one place and each kind of
/// action has a consistent strength: a *selection* tick for changing what is on
/// screen (switching tabs), a *light* tap for toggling a state (favouriting),
/// and a *medium* thump for finishing something (a chapter, a download).
void appHaptic(WidgetRef ref, [AppHaptic kind = AppHaptic.selection]) {
  if (!ref.read(appearanceSettingsProvider).hapticsEnabled) return;
  switch (kind) {
    case AppHaptic.selection:
      HapticFeedback.selectionClick();
    case AppHaptic.light:
      HapticFeedback.lightImpact();
    case AppHaptic.medium:
      HapticFeedback.mediumImpact();
  }
}
