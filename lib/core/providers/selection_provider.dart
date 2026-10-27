import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether any main screen is currently in long-press selection mode.
///
/// Kotatsu-Redo hides its bottom navigation bar while an action mode is
/// active (`bottomNav?.hide()` in `onSupportActionModeStarted`); mirroring
/// that here lets the floating nav pill slide away instead of sitting over
/// the selection bar's actions.
final selectionActiveProvider = StateProvider<bool>((ref) => false);