import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

/// Material 3 section header (labelMedium / onSurfaceVariant, title case).
class M3SectionHeader extends StatelessWidget {
  const M3SectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Shows a Material 3 modal bottom sheet with a drag handle, title and an
/// optionally pinned footer button. Content scrolls within [maxHeightFactor]
/// of the screen height. Popping the sheet (footer button, drag handle, tap
/// outside or back) resolves the returned future — the value passed to
/// `Navigator.pop` when dismissed from the footer, or `null` otherwise.
Future<T?> showM3ModalSheet<T>(
  BuildContext context, {
  required String title,
  required List<Widget> children,
  Widget? footer,
  double maxHeightFactor = 0.6,

  /// Optional glyph ahead of [title]. Sheets that pick a single setting use it
  /// to say what is being picked, so the title is not read in isolation.
  IconData? titleLeading,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * maxHeightFactor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: Row(
                  children: [
                    if (titleLeading != null) ...[
                      Icon(
                        titleLeading,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: footer,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Standard settings-screen app bar: themed foreground, transparent
/// background, large light-weight title and back arrow.
/// Present while a settings category screen is rendered inside a wide
/// two-pane settings layout.
///
/// A category screen in a pane has nothing behind it to go back to -- the
/// sibling categories are selections, not history -- so its app bar drops the
/// back button. Doing this through a scope rather than a constructor flag on
/// each screen means all of them pick it up without seven edits, and a screen
/// cannot end up with a back arrow that pops the whole settings route out from
/// under a pane tap.
class SettingsPaneScope extends InheritedWidget {
  const SettingsPaneScope({super.key, required super.child});

  /// Whether [context] sits inside a two-pane settings detail pane.
  static bool of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SettingsPaneScope>()
      != null;

  @override
  bool updateShouldNotify(SettingsPaneScope oldWidget) => false;
}

class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SettingsAppBar({super.key, required this.title, this.actions});

  final String title;

  /// Optional trailing widgets, e.g. an overflow menu button.
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: SettingsPaneScope.of(context)
          ? null
          : IconButton(
              icon: const Icon(RemixIcons.arrow_left_line),
              onPressed: () => Navigator.pop(context),
            ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
      ),
      actions: actions,
    );
  }
}