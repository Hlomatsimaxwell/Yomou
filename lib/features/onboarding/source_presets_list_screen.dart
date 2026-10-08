import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/features/onboarding/content_preferences_provider.dart';
import 'package:yomou/features/onboarding/source_presets_provider.dart';
import 'package:yomou/features/onboarding/source_presets_edit_sheet.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

class SourcePresetsListScreen extends ConsumerWidget {
  const SourcePresetsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(sourcePresetsProvider);
    final notifier = ref.read(sourcePresetsProvider.notifier);
    final prefs = ref.watch(contentPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.presetsManage),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: state.presets.length,
        itemBuilder: (context, i) {
          final p = state.presets[i];
          final isActive = p.id == state.activeId;
          final langCount = p.languages.length;
          final langs = p.languages.take(2).toList();
          final subtitle = langCount == 0
              ? l.presetsAllSources
              : '${langs.join(', ')}${langCount > 2 ? ' +${langCount - 2}' : ''}';
          return ListTile(
            leading: Radio<String>(
              value: p.id,
              groupValue: state.activeId,
              onChanged: (v) {
                if (v == null) return;
                notifier.activate(v);
              },
            ),
            title: Text(sourcePresetLabel(l, p)),
            subtitle: Text(subtitle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(RemixIcons.pencil_line),
                  onPressed: () => showSourcePresetEditSheet(context, preset: p),
                ),
                IconButton(
                  icon: const Icon(RemixIcons.delete_bin_line),
                  onPressed: p.isAll
                      ? null
                      : () => _confirmDelete(context, notifier, p, l),
                ),
              ],
            ),
            onTap: () => notifier.activate(p.id),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showSourcePresetEditSheet(context),
        child: const Icon(RemixIcons.add_line),
      ),
    );
  }

  void _confirmDelete(BuildContext context, SourcePresetsNotifier notifier,
      SourcePreset p, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.presetsDeleteConfirm(sourcePresetLabel(l, p))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.presetsCancel),
          ),
          TextButton(
            onPressed: () {
              notifier.delete(p.id);
              Navigator.pop(context);
            },
            child: Text(l.presetsDeleteAction),
          ),
        ],
      ),
    );
  }
}