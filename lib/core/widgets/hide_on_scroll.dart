import 'package:flutter/material.dart';

/// iOS-style collapsible top strip: the [header] (search bar, …) smoothly
/// collapses to nothing while the user scrolls down and expands again the
/// moment they scroll up (or return to the top).
///
/// The scrollable [body] fills the rest of the screen and gains the freed space
/// as the header collapses.
class HideOnScroll extends StatefulWidget {
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
  State<HideOnScroll> createState() => _HideOnScrollState();
}

class _HideOnScrollState extends State<HideOnScroll> {
  static const _duration = Duration(milliseconds: 220);
  static const _curve = Curves.easeOut;

  double _lastPixels = 0;
  bool _hidden = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final pixels = notification.metrics.pixels;
    final delta = pixels - _lastPixels;
    _lastPixels = pixels;

    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      if (delta > 1 && pixels > 0 && !_hidden) {
        setState(() => _hidden = true);
      } else if (delta < -1 || pixels <= 0) {
        if (_hidden) setState(() => _hidden = false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
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