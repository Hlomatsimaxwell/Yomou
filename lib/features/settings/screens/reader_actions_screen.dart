import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/theme/colors.dart';
import 'package:yomou/features/settings/providers/reader_actions_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// Settings > Reader actions: what a tap and a long tap do in each of the nine
/// zones the reader's screen is divided into.
///
/// The grid is drawn as one widget with a shared border pass rather than nine
/// nested containers, so the separators meet cleanly and the surface tint of a
/// mapped cell never shows through a hairline.
class ReaderActionsScreen extends ConsumerWidget {
  const ReaderActionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final zones = ref.watch(readerActionsProvider);
    final notifier = ref.read(readerActionsProvider.notifier);

    return Scaffold(
      appBar: SettingsAppBar(
        title: l.settingsReaderActions,
        actions: [
          IconButton(
            tooltip: l.ractMenuOverflow,
            icon: const Icon(RemixIcons.more_2_line),
            onPressed: () => _showOverflow(context, ref),
          ),
        ],
      ),
      // The grid is a map of the whole screen, so it gets the whole screen:
      // the app bar is the only chrome above it and nothing is inset from the
      // edges, which keeps each cell's proportions tied to the zones it stands
      // for.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Text(
              l.ractMenuSubtitle,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              // The grid is edge to edge, but not under the navigation bar:
              // the bottom row's tap targets would otherwise sit behind it and
              // the lower part of a cell would be untappable. The inset is the
              // only thing subtracted from the full height.
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: _ZoneGrid(
                zones: zones,
                onEdit: (row, column, gesture) => _pickAction(
                  context: context,
                  title: gesture == ZoneGesture.tap
                      ? l.ractTapAction
                      : l.ractLongTapAction,
                  selected: zones.action(row, column, gesture),
                  onSelect: (id) =>
                      notifier.setAction(row, column, gesture, id),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The kebab menu: Reset back to the defaults, or Disable all outright.
  static Future<void> _showOverflow(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(readerActionsProvider.notifier);

    final choice = await showM3ModalSheet<String>(
      context,
      title: l.ractMenuOverflow,
      children: [
        ListTile(
          title: Text(l.ractReset),
          onTap: () => Navigator.pop(context, 'reset'),
        ),
        ListTile(
          title: Text(l.ractDisableAll),
          onTap: () => Navigator.pop(context, 'disable'),
        ),
      ],
      footer: Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel,
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'reset') {
      await notifier.reset();
      messenger.showSnackBar(
        SnackBar(content: Text(l.ractResetDone), duration: _snackDuration),
      );
    } else {
      await notifier.disableAll();
      messenger.showSnackBar(
        SnackBar(content: Text(l.ractDisabledAll), duration: _snackDuration),
      );
    }
  }

  static const Duration _snackDuration = Duration(seconds: 2);

  /// The action picker: a radio list, one row per action, Cancel underneath.
  static Future<void> _pickAction({
    required BuildContext context,
    required String title,
    required String selected,
    required Future<void> Function(String) onSelect,
  }) async {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final picked = await showM3ModalSheet<String>(
      context,
      title: title,
      // The reference list asks for `hand_line`, which this icon set version
      // does not ship; `cursor_hand` is the same pointing-finger glyph.
      titleLeading: RemixIcons.cursor_hand,
      children: [
        // One RadioGroup around the whole list rather than a per-row
        // groupValue: that is the non-deprecated way to drive a radio set, and
        // it keeps a single selection even if the list is ever rebuilt.
        RadioGroup<String>(
          groupValue: selected,
          onChanged: (v) {
            if (v != null) Navigator.pop(context, v);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final id in kActIds)
                RadioListTile<String>(
                  value: id,
                  title: Text(actionLabel(l, id)),
                  activeColor: cs.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
            ],
          ),
        ),
      ],
      footer: Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel, style: TextStyle(color: cs.primary)),
        ),
      ),
    );
    if (picked == null) return;
    await onSelect(picked);
  }

  /// Shared by the grid and the picker so a value never reads one way in the
  /// cell and another way once it is chosen.
  static String actionLabel(AppLocalizations l, String id) {
    switch (id) {
      case kActNextPage:
        return l.ractActionNextPage;
      case kActPrevPage:
        return l.ractActionPrevPage;
      case kActNextChapter:
        return l.ractActionNextChapter;
      case kActPrevChapter:
        return l.ractActionPrevChapter;
      case kActToggleUi:
        return l.ractActionToggleUi;
      case kActShowMenu:
        return l.ractActionShowMenu;
      default:
        return l.ractActionNone;
    }
  }
}

/// The 3x3 grid. Each cell is a fixed-aspect tile with two tappable lines.
class _ZoneGrid extends StatelessWidget {
  const _ZoneGrid({required this.zones, required this.onEdit});

  final ZoneAssignment zones;
  final void Function(int row, int column, ZoneGesture gesture) onEdit;

  @override
  Widget build(BuildContext context) {
    // No padding and no fixed aspect ratio: the grid covers the whole area
    // below the subtitle. The delegate's default childAspectRatio of 1.0 would
    // force every cell square and leave a wide band empty under the last row on
    // a tall screen, so it is derived from the real box instead — the grid
    // mirrors the screen's own proportions, which is what makes a cell's size
    // mean the same thing on any device.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / kZoneColumns;
        final cellHeight = constraints.maxHeight / kZoneRows;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: kZoneColumns,
            // The gap is painted by the cell's own border, so the two halves of
            // a hairline meet in the middle instead of overlapping.
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
            childAspectRatio:
                cellHeight <= 0 ? 1 : cellWidth / cellHeight,
          ),
          itemCount: kZoneRows * kZoneColumns,
          itemBuilder: (context, index) {
            final row = index ~/ kZoneColumns;
            final column = index % kZoneColumns;
            return _ZoneCell(
              row: row,
              column: column,
              zones: zones,
              onEdit: onEdit,
            );
          },
        );
      },
    );
  }
}

class _ZoneCell extends StatelessWidget {
  const _ZoneCell({
    required this.row,
    required this.column,
    required this.zones,
    required this.onEdit,
  });

  final int row;
  final int column;
  final ZoneAssignment zones;
  final void Function(int row, int column, ZoneGesture gesture) onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mapped = zones.isMapped(row, column);

    // A mapped cell gets the accent surface so the grid reads as a map of what
    // is live, not just a list of values.
    final background = !mapped
        ? Colors.transparent
        : (dark ? kAccentSurface : cs.primary.withValues(alpha: 0.08));

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          right: BorderSide(
            color: dark ? Colors.white.withValues(alpha: 0.08) : cs.outlineVariant,
            width: column == kZoneColumns - 1 ? 0 : 1,
          ),
          bottom: BorderSide(
            color: dark ? Colors.white.withValues(alpha: 0.08) : cs.outlineVariant,
            width: row == kZoneRows - 1 ? 0 : 1,
          ),
          top: BorderSide(
            color: dark ? Colors.white.withValues(alpha: 0.08) : cs.outlineVariant,
            width: row == 0 ? 0 : 1,
          ),
          left: BorderSide(
            color: dark ? Colors.white.withValues(alpha: 0.08) : cs.outlineVariant,
            width: column == 0 ? 0 : 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _ZoneLine(
            label: AppLocalizations.of(context).ractTapAction,
            value: ReaderActionsScreen.actionLabel(
              AppLocalizations.of(context),
              zones.action(row, column, ZoneGesture.tap),
            ),
            assigned: zones.action(row, column, ZoneGesture.tap) != kActNone,
            onTap: () => onEdit(row, column, ZoneGesture.tap),
          ),
          _ZoneLine(
            label: AppLocalizations.of(context).ractLongTapAction,
            value: ReaderActionsScreen.actionLabel(
              AppLocalizations.of(context),
              zones.action(row, column, ZoneGesture.longTap),
            ),
            assigned:
                zones.action(row, column, ZoneGesture.longTap) != kActNone,
            onTap: () => onEdit(row, column, ZoneGesture.longTap),
          ),
        ],
      ),
    );
  }
}

/// One editable line inside a cell: a small muted label over a bold value.
class _ZoneLine extends StatelessWidget {
  const _ZoneLine({
    required this.label,
    required this.value,
    required this.assigned,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool assigned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.1,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.15,
                    // An unassigned value recedes so the bold ones are the ones
                    // that stand out in a glance across the grid.
                    fontWeight: assigned ? FontWeight.w700 : FontWeight.w400,
                    color: assigned ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
