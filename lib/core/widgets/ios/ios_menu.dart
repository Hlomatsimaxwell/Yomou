import 'package:flutter/material.dart';

import 'package:remixicon/remixicon.dart';
import 'ios_sheet.dart';

/// A single row in an [IosMenu]/[IosMenuButton] panel.
class IosMenuItem<T> {
  final T value;
  final String label;
  final IconData icon;
  final bool destructive;

  const IosMenuItem({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
  });
}

/// A three-dots button that opens an iOS-style action menu (a compact rounded
/// panel anchored at the bottom of the screen).
class IosMenuButton<T> extends StatelessWidget {
  final Color? iconColor;
  final List<IosMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  const IosMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ??
        (dark
            ? Colors.white.withValues(alpha: 0.8)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8));
    return AppSheetPress(
      child: Icon(RemixIcons.more_2_line, size: 24, color: color),
      onTap: () async {
        final result = await showIosMenu<T>(context, items: items);
        if (result != null) onSelected(result);
      },
    );
  }
}

/// Shows an iOS-style action menu panel. Returns the selected item value, or
/// null if dismissed.
Future<T?> showIosMenu<T>(
  BuildContext context, {
  required List<IosMenuItem<T>> items,
}) {
  return showIosMenuPanel(
    context,
    children: [
      for (var i = 0; i < items.length; i++) ...[
        IosMenuRow(
          icon: items[i].icon,
          label: items[i].label,
          destructive: items[i].destructive,
          onTap: () => Navigator.pop(context, items[i].value),
        ),
        if (i < items.length - 1) const IosMenuDivider(),
      ],
    ],
  );
}

/// Shows an iOS-style menu panel with arbitrary [children] rows (e.g. toggle
/// rows that stay open). Rows are responsible for closing the sheet themselves.
Future<T?> showIosMenuPanel<T>(
  BuildContext context, {
  required List<Widget> children,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    clipBehavior: Clip.none,
    useSafeArea: true,
    builder: (sheetContext) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 520,
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          decoration: BoxDecoration(
            color: iosSheetBackground(sheetContext),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );
    },
  );
}

/// A plain selectable row for [showIosMenuPanel]; dismisses the panel via
/// [onTap].
class IosMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const IosMenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = destructive
        ? const Color(0xFFFF453A)
        : (dark ? Colors.white : Theme.of(context).colorScheme.onSurface);
    return AppSheetPress(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 18),
            Icon(icon, size: 20, color: fg.withValues(alpha: 0.9)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }
}

/// A slim gap between rows inside a [showIosMenuPanel] (deliberately no line:
/// dividers make the app read as Android — iOS menus just breathe).
class IosMenuDivider extends StatelessWidget {
  const IosMenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 1);
  }
}

/// A toggle row (e.g. NSFW / incognito) inside an [showIosMenuPanel] sheet that
/// stays open while toggled.
class MenuToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const MenuToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppSheetPress(
      onTap: () => onChanged(!value),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 18),
            Icon(
              value ? RemixIcons.eye_off_line : RemixIcons.eye_line,
              size: 20,
              color: (dark
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface)
                  .withValues(alpha: 0.9),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color:
                      dark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: (v) => onChanged(v),
              activeColor: Colors.white,
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: dark ? const Color(0xFF3A3A3C) : Colors.black26,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// A tappable container with subtle iOS press feedback (used for menu rows).
class AppSheetPress extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const AppSheetPress({super.key, required this.child, required this.onTap});

  @override
  State<AppSheetPress> createState() => _AppSheetPressState();
}

class _AppSheetPressState extends State<AppSheetPress> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _pressed
            ? (dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08))
            : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}
