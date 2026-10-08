import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

/// The selectable pill behind the content-preference pickers.
///
/// Three states: unselected is a transparent surface with a hairline border;
/// selected tints the surface with the accent, colours the border and label,
/// and prefixes a checkmark so the state is not carried by colour alone.
class YomouChip extends StatelessWidget {
  const YomouChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.accent,
  });

  final String label;
  final bool selected;

  /// Accent used for the selected state. Falls back to the theme's primary so
  /// the chip still reads correctly wherever [accent] is not threaded through.
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveAccent = accent ?? colorScheme.primary;
    final dark = theme.brightness == Brightness.dark;

    final BorderSide border = selected
        ? BorderSide(color: effectiveAccent, width: 1.25)
        : BorderSide(color: theme.dividerColor);

    return Material(
      color: selected
          ? effectiveAccent.withValues(alpha: dark ? 0.22 : 0.12)
          : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: border),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(
                  RemixIcons.check_line,
                  size: 16,
                  color: effectiveAccent,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? effectiveAccent : colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
