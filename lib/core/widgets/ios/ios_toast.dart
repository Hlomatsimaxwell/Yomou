import 'dart:async';

import 'package:flutter/material.dart';

import 'package:yomou/core/theme/layout.dart';

/// The pill currently on screen, if any; showing a new toast replaces it.
OverlayEntry? _currentToastEntry;

/// Presents a compact, pill-shaped floating toast near the bottom of the
/// screen, with an optional trailing action (e.g. "Undo"). Automatically
/// dismisses after [duration], and replaces any toast already on screen.
///
/// Styled like the floating navigation pill (same surface colors, radius and
/// shadow) so it belongs to the theme, floats above the bottom bar, and never
/// swallows taps unless it carries a tappable action.
void showIosToast(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  showIosToastOnOverlay(
    Overlay.of(context, rootOverlay: true),
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
  );
}

/// Same compact pill for callers that captured an [OverlayState] before an
/// `await`: no BuildContext crosses the gap, and the root overlay (and its
/// safe-area metrics) survives the originating route, so the toast still
/// appears even when that route is gone.
void showIosToastOnOverlay(
  OverlayState overlay, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  _currentToastEntry?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _IosToastPill(
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      onDismissed: () {
        if (identical(_currentToastEntry, entry)) {
          _currentToastEntry = null;
        }
        entry.remove();
      },
    ),
  );
  _currentToastEntry = entry;
  overlay.insert(entry);
}

/// Convenience wrapper for an undo-style toast.
void showIosUndoToast(
  BuildContext context, {
  required String message,
  required String undoLabel,
  required VoidCallback onUndo,
}) {
  showIosToast(
    context,
    message: message,
    actionLabel: undoLabel,
    onAction: onUndo,
  );
}

/// A pill-shaped floating toast: capsule surface with a circular entry, like
/// the import scan pill. Fades/scales in, sits above the bottom bar, and is
/// wrapped in [IgnorePointer] unless it carries an action so it can never
/// block a tap anywhere on the screen.
class _IosToastPill extends StatefulWidget {
  const _IosToastPill({
    required this.message,
    this.actionLabel,
    this.onAction,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_IosToastPill> createState() => _IosToastPillState();
}

class _IosToastPillState extends State<_IosToastPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  bool get _hasAction => widget.actionLabel != null && widget.onAction != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
    _timer = Timer(widget.duration, () {
      if (!mounted) return;
      _controller.reverse().whenComplete(widget.onDismissed);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleAction() {
    widget.onDismissed();
    widget.onAction?.call();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = Theme.of(context).colorScheme.onSurface;
    final pillColor = dark ? const Color(0xF21C1C1E) : Colors.white;
    final pillBorder = dark
        ? const Color(0x332C2C30)
        : Colors.black.withValues(alpha: 0.08);

    // Sits just above the floating/solid bottom bar on the tabbed screens. On
    // pushed routes that have no bar it floats a little higher, which still
    // reads as a notification.
    final bottomGap = bottomBarTopEdge(context) + 12;

    return IgnorePointer(
      ignoring: !_hasAction,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomGap),
          child: FadeTransition(
            opacity: _controller,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: pillBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_hasAction) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _handleAction,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Text(
                            widget.actionLabel!,
                            style: const TextStyle(
                              color: Color(0xFF64AFFF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}