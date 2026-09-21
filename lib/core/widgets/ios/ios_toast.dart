import 'package:flutter/material.dart';

import 'package:yomou/core/theme/layout.dart';

/// Presents an iOS-style floating toast near the bottom of the screen, with an
/// optional trailing action (e.g. "Undo"). Automatically dismisses after
/// [duration], and hides any toast already on screen.
void showIosToast(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.of(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  final background = dark ? const Color(0xFF1C1C1E) : Colors.white;
  final textColor = dark ? Colors.white : const Color(0xFF1C1B1F);
  // Reuse the accent blue for the action in both modes (Kotatsu-tinted).
  const actionColor = Color(0xFF64AFFF);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: actionColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: dark ? BorderSide.none : const BorderSide(color: Colors.black12),
        ),
        margin: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + bottomBarClearance(context),
        ),
        duration: duration,
      ),
    );
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
