import 'package:flutter/material.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';

/// Presents [builder] as a panel anchored to the right edge on a wide window,
/// and as a bottom sheet on a phone.
///
/// The two are different presentations of the same content, not two content
/// sets. A centred dialog over a full-bleed page is the wrong shape on a
/// desktop: it covers the page you are reading to change a setting about the
/// page you are reading, and a bottom sheet that stops short of the full width
/// leaves the two halves of the screen unrelated to each other. Anchoring to
/// the right keeps the page visible on the left and puts the controls in the
/// column a side panel is expected to occupy.
///
/// On a phone this is [showIosSheet] unchanged -- the app's one bottom sheet,
/// with its grabber and its top-only rounding. A panel the width of the screen
/// would just be a full-screen page with extra steps, and the bottom sheet is
/// the platform's own answer.
///
/// This is a thin named wrapper over [showIosSheet]'s panel presentation: the
/// reader's panel, the welcome sheet and every options sheet in the app are one
/// shape, so there is one place where how that shape behaves is decided.
Future<T?> showReaderSidePanel<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showIosSheet<T>(
    context,
    title: title,
    isScrollControlled: isScrollControlled,
    builder: builder,
  );
}
