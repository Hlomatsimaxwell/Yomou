import 'package:flutter/material.dart';

/// Surfaces for a settings screen, kept in one place so the sidebar, the
/// detail pane and the cards inside it cannot drift apart.
///
/// The shape is the iPadOS one: a sidebar that is its own column, a detail
/// pane on a different tone, and cards on the pane. Light mode is white cards
/// on a light grey pane; dark mode is dark cards on the app's pure black pane,
/// which is the tone the rest of the app already uses for dark surfaces.
class SettingsSurfaces {
  const SettingsSurfaces._();

  /// Sidebar column. Slightly inset from the cards so the two columns read as
  /// different planes even where the divider is not visible.
  static Color sidebar(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF141416) : Colors.white;
  }

  /// The detail pane behind the cards.
  ///
  /// A tone rather than [Theme]'s scaffold colour on purpose: the pane needs to
  /// differ from the sidebar, and on a phone there is no sidebar for it to
  /// differ from -- the cards have to read as cards against the plain
  /// background, so the pane carries the tint in both layouts.
  static Color pane(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7);
  }

  /// Card fill inside the pane.
  static Color card(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF1C1C1E) : Colors.white;
  }

  /// Hairline card edge.
  ///
  /// Present in both brightnesses, deliberately. On a phone there is no pane
  /// tint behind the cards, so a white card on the near-white scaffold has
  /// almost nothing to separate it by and the edge is the only thing that draws
  /// the corner. Rather than give up the inset look on the layout that cannot
  /// show it, both layouts get the hairline.
  static Color cardBorder(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? Colors.white.withValues(alpha: 0.08)
        : Theme.of(context).colorScheme.outlineVariant;
  }

  /// Divider between rows inside a card.
  static Color divider(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  /// Divider between the sidebar and the detail pane.
  static Color columnDivider(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? Colors.white12 : Colors.black12;
  }
}

/// A run of settings rows on one card.
///
/// Rows are separated by hairlines inset to the start of their labels rather
/// than their icons, which is what makes a card read as one block instead of a
/// stack of separate rows: the divider lines up with the text, so the icons sit
/// in a gutter beside it rather than being cut in half.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  final List<Widget> children;

  /// Optional small uppercase-style label above the card. Left out where the
  /// app has no name for the group rather than inventing one.
  final String? header;

  /// Optional muted line under the card, for a note that belongs to the group.
  final Widget? footer;
  /// Inset of the divider from the card's left edge: the row's own padding, the
  /// icon, and the gap after it.
  static const double _dividerInset = 54;

  @override
  Widget build(BuildContext context) {
    // A Material, not a DecoratedBox with a fill. A ListTile paints its ink
    // splash on the nearest Material ancestor, so a painted box between the two
    // hides the splash entirely -- the row looks inert. The card is the
    // surface the rows are supposed to be interacting with, so it is the
    // Material.
    final card = Material(
      color: SettingsSurfaces.card(context),
      // Clipped so a row's ink splash follows the card's rounded corners
      // instead of spilling out square at the top and bottom of the run.
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: SettingsSurfaces.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: _dividerInset),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: SettingsSurfaces.divider(context),
                ),
              ),
            children[i],
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              // Inset to the label column, not the card edge, so the header
              // reads as belonging to the rows under it rather than floating
              // over the card's left margin.
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                header!.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          card,
          if (footer != null) ...[
            const SizedBox(height: 8),
            footer!,
          ],
        ],
      ),
    );
  }
}
