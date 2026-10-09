import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/features/content_preferences/widgets/content_preferences_editor.dart';
import 'package:yomou/features/content_preferences/screens/source_presets_edit_sheet.dart';
import 'package:yomou/features/content_preferences/providers/source_presets_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// The full preset manager, reached from Explore's preset row.
///
/// A radio column rather than the chip switcher: choosing a preset here is a
/// deliberate act, and the list has room to spell out the languages each one
/// carries and to offer rename/delete next to every row.
class SourcePresetsListScreen extends ConsumerWidget {
  const SourcePresetsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(sourcePresetsProvider);
    final notifier = ref.read(sourcePresetsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.presetsManage),
      ),
      body: RadioGroup<String>(
        groupValue: state.activeId,
        onChanged: (value) {
          if (value == null) return;
          notifier.activate(value);
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
          itemCount: state.presets.length,
          itemBuilder: (context, i) {
            final p = state.presets[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: Radio<String>(value: p.id),
              title: Text(sourcePresetLabel(l, p)),
              subtitle: Text(_subtitle(l, p)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(RemixIcons.pencil_line),
                    tooltip: l.presetsEdit,
                    // "All sources" is built in: its name is localized and its
                    // empty language set is the whole point, so there is
                    // nothing here to edit.
                    onPressed: p.isAll
                        ? null
                        : () => showSourcePresetEditSheet(context, preset: p),
                  ),
                  IconButton(
                    icon: const Icon(RemixIcons.delete_bin_line),
                    tooltip: l.presetsDelete,
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showSourcePresetEditSheet(context),
        child: const Icon(RemixIcons.add_line),
      ),
    );
  }

  /// One line naming the languages a preset keeps, in the reader's own words.
  String _subtitle(AppLocalizations l, SourcePreset p) {
    if (p.languages.isEmpty) return l.presetsAllSources;
    final names =
        p.languages.map((lang) => contentLanguageLabel(l, lang)).toList();
    final shown = names.take(3).join(', ');
    return names.length > 3 ? '$shown +${names.length - 3}' : shown;
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
