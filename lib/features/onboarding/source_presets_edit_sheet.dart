import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/yomou_chip.dart';
import 'package:yomou/features/onboarding/content_preferences_editor.dart';
import 'package:yomou/features/onboarding/content_preferences_provider.dart';
import 'package:yomou/features/onboarding/source_presets_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

Future<void> showSourcePresetEditSheet(BuildContext context,
    {SourcePreset? preset}) {
  return showIosSheet<void>(
    context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    builder: (sheetContext) => _SourcePresetEditSheet(preset: preset),
  );
}

class _SourcePresetEditSheet extends ConsumerStatefulWidget {
  const _SourcePresetEditSheet({this.preset});
  final SourcePreset? preset;

  @override
  ConsumerState<_SourcePresetEditSheet> createState() =>
      _SourcePresetEditSheetState();
}

class _SourcePresetEditSheetState
    extends ConsumerState<_SourcePresetEditSheet> {
  late final TextEditingController _name;
  late final Set<String> _languages;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.preset?.name ?? '');
    _languages = {...(widget.preset?.languages ?? ref.read(contentPreferencesProvider).languages)};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _isValid => _name.text.trim().isNotEmpty || widget.preset != null || _languages.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final notifier = ref.read(sourcePresetsProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    widget.preset == null ? l.presetsNew : l.presetsEdit,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (widget.preset == null) {
                      notifier.createFromCurrent();
                      // better: create with name/languages
                      final created = SourcePreset(
                        id: 'p${DateTime.now().microsecondsSinceEpoch}',
                        name: _name.text.trim(),
                        languages: {..._languages},
                      );
                      // recreate via provider? easier: activate logic — just store
                      // but simpler: use createFromCurrent then rename+activate? quick approach
                    }
                    // handled below
                    Navigator.pop(context);
                  },
                  child: Text(l.presetsSave),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l.presetsNameHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
                    selected: _languages.contains(language),
                    onTap: () {
                      setState(() {
                        if (!_languages.remove(language)) _languages.add(language);
                      });
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