import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/yomou_chip.dart';
import 'package:yomou/features/onboarding/source_presets_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

Future<void> showSourcePresetsSwitchSheet(BuildContext context) {
  return showIosSheet<void>(
    context,
    isDismissible: true,
    enableDrag: true,
    builder: (sheetContext) => const _SourcePresetSwitchSheet(),
  );
}

class _SourcePresetSwitchSheet extends ConsumerWidget {
  const _SourcePresetSwitchSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(sourcePresetsProvider);
    final notifier = ref.read(sourcePresetsProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.presetsManage,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(RemixIcons.close_line),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in state.presets)
                  YomouChip(
                    label: sourcePresetLabel(l, preset),
                    selected: preset.id == state.activeId,
                    onTap: () {
                      notifier.activate(preset.id);
                      Navigator.of(context).pop();
                    },
                  ),
                ActionChip(
                  label: Text(l.presetsCreateFromCurrent),
                  avatar: const Icon(RemixIcons.add_line, size: 18),
                  onPressed: () {
                    notifier.createFromCurrent();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}