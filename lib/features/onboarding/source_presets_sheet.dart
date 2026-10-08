import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/yomou_chip.dart';
import 'package:yomou/features/onboarding/content_preferences_editor.dart';
import 'package:yomou/features/onboarding/content_preferences_provider.dart';
import 'package:yomou/features/onboarding/source_presets_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

Future<void> showSourcePresetsSheet(BuildContext context) {
  return showIosSheet<void>(
    context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    builder: (sheetContext) => const _SourcePresetsSheet(),
  );
}

class _SourcePresetsSheet extends ConsumerWidget {
  const _SourcePresetsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(sourcePresetsProvider);
    final notifier = ref.read(sourcePresetsProvider.notifier);
    final prefs = ref.watch(contentPreferencesProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.presetsManage,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(RemixIcons.close_line),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                  label: Text(l.presetsNew),
                  avatar: const Icon(RemixIcons.add_line, size: 18),
                  onPressed: () {
                    notifier.createFromCurrent();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(l.presetsLanguages, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final language in kContentLanguages)
                  YomouChip(
                    label: contentLanguageLabel(l, language),
                    selected: prefs.languages.contains(language),
                    onTap: () => ref.read(contentPreferencesProvider.notifier).toggleLanguage(language),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}