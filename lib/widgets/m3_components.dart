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
/// of the screen height. Returns when the sheet is dismissed.
Future<void> showM3ModalSheet(
  BuildContext context, {
  required String title,
  required List<Widget> children,
  Widget? footer,
  double maxHeightFactor = 0.6,
}) {
  return showModalBottomSheet<void>(
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
                child: Text(
                  title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
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
class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SettingsAppBar({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(RemixIcons.arrow_left_line),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
      ),
    );
  }
}