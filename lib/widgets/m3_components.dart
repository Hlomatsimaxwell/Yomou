import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/widgets/responsive.dart';

/// Material 3 section header (titleSmall-ish / primary, title case).
///
/// Tinted with the scheme's primary rather than onSurfaceVariant, so a section
/// boundary reads as part of the app's accent rather than as a slightly
/// bolder body label. Used app-wide, so this is one decision, not a per-screen
/// preference.
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
          color: cs.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
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

/// Single-select option sheet: a row per choice, a plain check on the current
/// one, and no footer.
///
/// The shape every Settings picker uses. Tapping a row applies the choice and
/// closes the sheet, so there is nothing left to confirm and no Cancel to
/// offer -- the sheet itself is the list, not a form around it. The tick is the
/// same plain `check_line` the appearance sheets use, never a radio or a circled
/// box, because only one value is ever chosen.
///
/// [selected] is compared with `==`, so [T] can be any value type and callers
/// hand back the stored id rather than a label.
Future<T?> showM3OptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  required T selected,
  IconData? titleLeading,
  double maxHeightFactor = 0.6,
}) {
  final cs = Theme.of(context).colorScheme;
  return showM3ModalSheet<T>(
    context,
    title: title,
    titleLeading: titleLeading,
    maxHeightFactor: maxHeightFactor,
    children: [
      for (final (id, label) in options)
        ListTile(
          title: Text(label),
          trailing: id == selected
              ? Icon(RemixIcons.check_line, color: cs.primary)
              : null,
          onTap: () => Navigator.pop(context, id),
        ),
    ],
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

  /// The one app-bar title style, shared by the phone bar and the pane bar so
  /// the two cannot drift apart.
  static const TextStyle titleStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w400,
  );

  /// The column's own content margin: a `ListTile`'s start padding, and what a
  /// section header is inset by. A pane title lines up with it rather than with
  /// the pane's edge.
  static const double _contentMargin = 16;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Inside a pane there is nothing behind this screen to go back to -- the
    // sibling categories are a selection, not history -- so the arrow goes.
    if (!SettingsPaneScope.of(context)) {
      return AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(RemixIcons.arrow_left_line),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: titleStyle),
        actions: actions,
      );
    }

    // The pane's body is a centred, width-capped column, so a title pinned to
    // the pane's own left edge sits out in the empty gutter whenever the pane
    // is wider than the cap -- which is exactly the case on a tablet, where the
    // title ended up ~70px left of everything under it. Laying the bar out
    // against the pane's width lets the title start on the same line as the
    // column's content margin instead.
    //
    // The empty leading is not incidental. `leading: null` alone is not enough:
    // AppBar then falls back to automatically implying a back button whenever
    // the route can pop, which inside a pushed route it always can, so the
    // arrow comes back. At zero width it reserves none of the bar either, which
    // the title offset below relies on: the toolbar starts the title at
    // `leadingWidth + titleSpacing`.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = widthClassOf(context).contentMaxWidth;
        final gutter = constraints.maxWidth > cap
            ? (constraints.maxWidth - cap) / 2
            : 0.0;
        return AppBar(
          automaticallyImplyLeading: false,
          leading: const SizedBox.shrink(),
          leadingWidth: 0,
          titleSpacing: gutter + _contentMargin,
          title: Text(title, style: titleStyle),
          actions: actions,
        );
      },
    );
  }
}