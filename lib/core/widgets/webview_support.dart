import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show InAppWebViewPlatform;
import 'package:yomou/l10n/generated/app_localizations.dart';

import 'empty_state.dart';

/// Whether a real InAppWebView platform implementation is registered.
///
/// The plugin ships implementations for Android, iOS, macOS, Windows and the
/// web, but not for Linux desktop. On a platform without one,
/// `InAppWebViewPlatform.instance` throws an assertion rather than returning
/// null, so this has to probe it inside a try instead of comparing it to null.
///
/// Reading the instance and discarding the result looks wrong, so it is
/// assigned: this is a reachability probe, not an unused getter call.
bool get inAppWebViewAvailable {
  try {
    final platform = InAppWebViewPlatform.instance;
    return platform != null;
  } catch (_) {
    return false;
  }
}

/// Stands in for a webview body on a platform that has no webview.
///
/// Building an `InAppWebView` without a platform implementation does not fail
/// gracefully: the widget asserts in its constructor and paints a red error
/// box, which on a pushed route covers the app and swallows every tap behind
/// it. An honest message that explains why the screen cannot open is the
/// lesser failure, and it says what to do instead of leaving a dead screen.
class WebviewUnavailableBody extends StatelessWidget {
  const WebviewUnavailableBody({super.key, this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: icon ?? Icons.language_outlined,
      title: l10n.webviewMissingTitle,
      subtitle: l10n.webviewMissingBody,
    );
  }
}
