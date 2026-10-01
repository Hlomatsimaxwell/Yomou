import 'package:flutter/material.dart';

/// Surfaces for a settings screen, kept in one place so the sidebar and the
/// detail pane cannot drift apart.
///
/// The shape is the iPadOS one: a sidebar that is its own column, a detail pane
/// on a different tone behind it. Light mode is a white sidebar on a light grey
/// pane; dark mode is a near-black sidebar on the app's pure black pane, which
/// is the tone the rest of the app already uses for dark surfaces.
class SettingsSurfaces {
  const SettingsSurfaces._();

  /// Sidebar column.
  static Color sidebar(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF141416) : Colors.white;
  }

  /// The detail pane behind the category's own list.
  ///
  /// A tone rather than [Theme]'s scaffold colour on purpose: the pane needs to
  /// differ from the sidebar, and on a phone there is no sidebar for it to
  /// differ from, so the pane carries the tint in both layouts.
  static Color pane(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7);
  }

  /// Divider between the sidebar and the detail pane.
  static Color columnDivider(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? Colors.white12 : Colors.black12;
  }
}