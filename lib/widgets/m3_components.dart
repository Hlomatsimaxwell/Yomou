import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:yomou/core/theme/hairline.dart';
import 'package:yomou/core/widgets/responsive.dart';

/// Material 3 section header (titleSmall-ish / primary, title case).
///
/// Tinted with the scheme's primary rather than onSurfaceVariant, so a section
/// boundary reads as part of the app's accent rather than as a slightly
/// bolder body label. Used app-wide, so this is one decision, not a per-screen
/// preference.
///
/// The vertical rhythm is the same everywhere too: 24 above the label, 16
/// between it and the first item under it. The heading owns both gaps instead
/// of leaving them to whatever precedes it, so two groups read the same
/// distance apart whether the row above them is one line, two lines or a
/// carousel -- and a screen never has to add a spacer of its own to get a
/// break it thinks is bigger.
///
/// The break is also drawn: a hairline across the top of the heading, which is
/// what says the rows under it are a new set rather than a continuation of the
/// ones above. It sits inside the 24, so the rule and the label are one block
/// and nothing has to be inserted between two groups.
class M3SectionHeader extends StatelessWidget {
  const M3SectionHeader({
    super.key,
    required this.title,
    this.dividerAbove = true,
    this.bleed = 0,
  });

  final String title;

  /// Whether to draw the rule over the label. Off for a heading that opens its
  /// list: there is nothing above it for a rule to separate it from, and one
  /// under the bar reads as a border around the screen rather than as a break
  /// in it.
  final bool dividerAbove;

  /// How far the rule reaches past this heading's own box on each side so that
  /// it can land on the edges of the surface it divides. A list that insets
  /// itself horizontally passes that inset here; a heading already sitting
  /// flush in its list leaves this at 0. Overshooting is harmless -- the list
  /// clips the rule back at the surface's edge.
  final double bleed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dividerAbove)
          // Add a touch of air above the rule so the previous row doesn't sit
          // right on top of the separator.
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -bleed,
                    right: -bleed,
                    top: 0,
                    bottom: 0,
                    child: ColoredBox(color: hairlineColor(context)),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Text(
            title,
            style: TextStyle(
              color: cs.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
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
              ? Icon(MdiIcons.check, color: cs.primary)
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
class SettingsPaneScope extends StatelessWidget {
  const SettingsPaneScope({super.key, required this.child});

  final Widget child;

  /// Whether [context] sits inside a two-pane settings detail pane.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SettingsPane>() != null;

  @override
  Widget build(BuildContext context) {
    // The pane is the measure. Every screen under it would otherwise cap
    // itself at the width class's 960, which on a pane wider than that centres
    // the cap and leaves the rows' switches and the slider's track short of
    // the edge they are supposed to sit on -- the pane's own edge, which is
    // where a pushed copy of the same screen puts them.
    return ContentWidthCap(
      cap: double.infinity,
      child: _SettingsPane(child: child),
    );
  }
}

/// The marker behind [SettingsPaneScope.of].
class _SettingsPane extends InheritedWidget {
  const _SettingsPane({required super.child});

  @override
  bool updateShouldNotify(_SettingsPane oldWidget) => false;
}

/// The row rhythm a settings list uses: one height for every row in it.
///
/// Material's own is 72 for a row with a subtitle under it and 56 for one
/// without, which reads as two different lists when both sit in one column.
/// A settings row here is a name over one line of its value -- 24 + 20 of
/// text -- so 52 is that text with [rowInset] above and below: the tightest
/// that still holds both lines, and the same height whether the row carries a
/// subtitle or not.
class SettingsRows extends StatelessWidget {
  const SettingsRows({super.key, required this.child});

  final Widget child;

  /// A row carrying a subtitle: 24 + 20 of text plus [rowInset] above and
  /// below. A one-line row is held to the same height so the column keeps one
  /// rhythm.
  static const double rowHeight = 60;

  /// The breathing room a row keeps inside [rowHeight].
  static const double rowInset = 8;

  /// How far a row's trailing control is held off the pane's own edge, once
  /// the list's own 8 is added. Material's tile ends 24 in; at a pane's width
  /// that reads as a gap, so the switches are brought in to the edge.
  static const double trailingInset = 8;

  @override
  Widget build(BuildContext context) {
    return ListTileTheme(
      data: Theme.of(context).listTileTheme.copyWith(
            minTileHeight: rowHeight,
            minVerticalPadding: rowInset,
            // Material gives a tile 16 at the start and 24 at the end. A pane
            // is the measure the rows are drawn against, so the extra 8 at the
            // end reads as a gap between a switch and the edge it sits on
            // rather than as symmetry. The start stays at 16, where it is what
            // lines a row's icon up with the pane's title and section labels.
            contentPadding: const EdgeInsetsDirectional.only(
              start: 16,
              end: trailingInset,
            ),
          ),
      child: child,
    );
  }
}

class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SettingsAppBar({
    super.key,
    required this.title,
    this.actions,
    this.contentMargin = _contentMargin,
  });

  final String title;

  /// Optional trailing widgets, e.g. an overflow menu button.
  final List<Widget>? actions;

  /// How far the title is inset when this bar belongs to a pane. A screen whose
  /// content sits on a wider guide than the default passes its own, so the
  /// title keeps starting on the same line as the column beneath it.
  final double contentMargin;

  /// The one app-bar title style, shared by the phone bar and the pane bar so
  /// the two cannot drift apart. A settings screen's name is a heading over its
  /// groups, so it is sized as one: a step above the rows under it rather than
  /// level with the group labels, which left the name of the screen looking
  /// like one more section in it.
  static const TextStyle titleStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  /// The column's own content margin: a `ListTile`'s start padding, and what a
  /// section header is inset by. A pane title lines up with it rather than with
  /// the pane's edge.
  static const double _contentMargin = 16;

  /// [titleStyle] in the surface's own foreground rather than the accent. The
  /// accent is what marks the group labels as labels; a title wearing it too
  /// read as the first of them, and it is the one line on the screen that is a
  /// name rather than a control.
  static TextStyle _titleStyle(BuildContext context) =>
      titleStyle.copyWith(color: Theme.of(context).colorScheme.onSurface);

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
          icon: const Icon(MdiIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: _titleStyle(context)),
        actions: actions,
      );
    }

    // The pane's body may or may not be a centred, width-capped column: a pane
    // is the measure and its screens stretch to it, but a screen that still
    // asks for a readable column caps itself and is then centred inside the
    // pane. Either way a title pinned to the pane's own left edge sits out in
    // the empty gutter beside the column, so the title reads the same cap the
    // body did -- the [ContentWidthCap] the body resolves -- and starts on the
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
        final cap = ContentWidthCap.maybeOf(context) ??
            widthClassOf(context).contentMaxWidth;
        final gutter = constraints.maxWidth > cap
            ? (constraints.maxWidth - cap) / 2
            : 0.0;
        return AppBar(
          automaticallyImplyLeading: false,
          leading: const SizedBox.shrink(),
          leadingWidth: 0,
          titleSpacing: gutter + contentMargin,
          title: Text(title, style: _titleStyle(context)),
          actions: actions,
        );
      },
    );
  }
}