import 'package:flutter/material.dart';

Color iosSheetBackground(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark ? const Color(0xFF1C1C1E) : Colors.white;
}

Color iosSheetGrabber(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark ? const Color(0xFF6E6E73) : Colors.black26;
}

/// Presents an iOS-style bottom sheet with a grabber handle, dark surface and
/// corners rounded only at the top.
Future<T?> showIosSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  double maxWidth = 520,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    clipBehavior: Clip.none,
    useSafeArea: true,
    builder: (sheetContext) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: maxWidth,
          child: Material(
            // A [Material], not a coloured [Container]. A ListTile paints its
            // background and its ink splash on the nearest Material ancestor, so
            // anything coloured sitting between the tile and that Material hides
            // both -- which is exactly what a BoxDecoration behind the sheet's
            // content did. Every sheet with a row in it lost its press
            // feedback, and debug builds reported it on every tap.
            color: iosSheetBackground(sheetContext),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            // The corners are rounded, so the splash has to be clipped to them
            // or it washes over the sheet's outline.
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: isScrollControlled
                  ? BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.92,
                    )
                  : const BoxConstraints(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 10, bottom: 6),
                    child: _IosGrabber(),
                  ),
                  Flexible(child: Builder(builder: builder)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _IosGrabber extends StatelessWidget {
  const _IosGrabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: iosSheetGrabber(context),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
