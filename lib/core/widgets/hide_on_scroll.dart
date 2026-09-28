import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/providers/appearance_provider.dart';

/// iOS-style collapsible top strip: the [header] (search bar, …) smoothly
/// collapses to nothing while the user scrolls down and expands again the
/// moment they scroll up (or return to the top).
///
/// The scrollable [body] fills the rest of the screen and gains the freed space
/// as the header collapses.
///
/// The strip stays pinned (never collapses) whenever the user has enabled
/// "pin navigation UI" (`pinNavUiOnScroll`), keeping it in lockstep with the
/// floating nav pill instead of peeling away from it mid-scroll.
class HideOnScroll extends ConsumerStatefulWidget {
  const HideOnScroll({
    super.key,
    required this.header,
    required this.body,
  });

  /// The top strip that should collapse on scroll-down.
  final Widget header;

  /// The scrollable content that fills the remaining space.
  final Widget body;

  @override
  ConsumerState<HideOnScroll> createState() => _HideOnScrollState();
}

class _HideOnScrollState extends ConsumerState<HideOnScroll> {
  static const _duration = Duration(milliseconds: 220);
  static const _curve = Curves.easeOut;

  final GlobalKey _headerKey = GlobalKey();
  double _lastPixels = 0;
  bool _hidden = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final metrics = notification.metrics;
    final pixels = metrics.pixels;
    final delta = pixels - _lastPixels;
    _lastPixels = pixels;

    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      // Collapsing grows the viewport by the header height, which shrinks
      // maxScrollExtent by exactly that much. If `pixels` then exceeds the new
      // extent the scroll offset gets re-clamped, and the content is displaced
      // by however much could not be scrolled - a jump the user never asked
      // for. That clamp cannot fire while at least a header-height of content
      // remains below the current offset, which is exactly this condition, so
      // the collapse is provably free here rather than merely usually safe.
      //
      // A list shorter than the header therefore never collapses, instead of
      // teleporting its content on every overscroll at the far end.
      final headerHeight = _headerKey.currentContext?.size?.height ?? 0;
      final roomBelow = metrics.maxScrollExtent - pixels;
      if (delta > 1 && pixels > 0 && !_hidden && roomBelow >= headerHeight) {
        setState(() => _hidden = true);
      } else if (delta < -1 || pixels <= 0) {
        if (_hidden) setState(() => _hidden = false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final pinned =
        ref.watch(appearanceSettingsProvider).pinNavUiOnScroll;
    if (pinned && _hidden) {
      final prevHidden = _hidden;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && prevHidden && _hidden) setState(() => _hidden = false);
      });
    }

    return NotificationListener<ScrollNotification>(
      onNotification: pinned ? null : _onScroll,
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              key: _headerKey,
              duration: _duration,
              curve: _curve,
              alignment: Alignment.topCenter,
              child: _hidden
                  ? const SizedBox(width: double.infinity)
                  : widget.header,
            ),
            Expanded(child: widget.body),
          ],
        ),
      ),
    );
  }
}