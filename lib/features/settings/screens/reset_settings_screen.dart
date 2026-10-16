import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:yomou/core/settings/settings_reset.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/main.dart' show restartApp;
import 'package:yomou/widgets/m3_components.dart';

/// Restores settings or wipes the app back to a fresh install.
///
/// Two deliberately separate actions: "Reset settings" clears the areas the
/// reader ticks and keeps their library, history and downloads; "Erase all
/// data" deletes everything and needs the word typed out. The gap between them
/// is the whole design -- an accidental tap must never cost a library.
class ResetSettingsScreen extends StatefulWidget {
  const ResetSettingsScreen({super.key});

  @override
  State<ResetSettingsScreen> createState() => _ResetSettingsScreenState();
}

class _ResetSettingsScreenState extends State<ResetSettingsScreen> {
  final Set<SettingsGroup> _selected = {};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final groups = <(SettingsGroup, IconData, String)>[
      (
        SettingsGroup.appearance,
        MdiIcons.paletteOutline,
        l.settingsGroupAppearance,
      ),
      (
        SettingsGroup.contentPreferences,
        MdiIcons.earth,
        l.settingsGroupContent,
      ),
      (SettingsGroup.reader, MdiIcons.bookOpenVariant, l.settingsGroupReader),
      (
        SettingsGroup.notifications,
        MdiIcons.rss,
        l.settingsGroupNotifications,
      ),
      (
        SettingsGroup.storage,
        MdiIcons.downloadOutline,
        l.settingsGroupStorage,
      ),
      (SettingsGroup.sources, MdiIcons.applicationOutline, l.settingsGroupSources),
    ];

    return Scaffold(
      appBar: SettingsAppBar(title: l.settingsReset),
      body: CappedContentWidth(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          M3SectionHeader(title: l.settingsResetSettingsSection),
          _Hint(text: l.settingsResetSettingsSubtitle),
          for (final (group, icon, label) in groups)
            CheckboxListTile(
              value: _selected.contains(group),
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      if (value == true) {
                        _selected.add(group);
                      } else {
                        _selected.remove(group);
                      }
                    }),
              secondary: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
              title: Text(label),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty || _busy ? null : _resetSelected,
                child: Text(l.settingsResetSelected),
              ),
            ),
          ),
          const SizedBox(height: 28),
          M3SectionHeader(title: l.settingsEraseSection),
          _Hint(text: l.settingsEraseSubtitle),
          ListTile(
            leading: Icon(
              MdiIcons.deleteOutline,
              color: theme.colorScheme.error,
            ),
            title: Text(
              l.settingsEraseTitle,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: _busy ? null : _confirmErase,
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _resetSelected() async {
    final l = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme;

    final confirmed = await showM3ModalSheet<bool>(
      context,
      title: l.settingsResetConfirmTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
          child: Text(
            l.settingsResetConfirmBody,
            style: TextStyle(fontSize: 14, color: color.onSurfaceVariant),
          ),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.settingsResetCancel),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.settingsResetSelected),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await resetSettings(_selected.toSet());
    if (!mounted) return;
    // Rebuild the tree and every provider so the defaults take effect at once.
    restartApp();
  }

  static const String _eraseWord = 'DELETE';

  /// The heavier guard: the reader has to type [_eraseWord] before the button
  /// that deletes their library, history and downloads becomes tappable.
  Future<void> _confirmErase() async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final color = Theme.of(dialogContext).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final matches =
                controller.text.trim().toUpperCase() == _eraseWord;
            return AlertDialog(
              title: Text(l.settingsEraseConfirmTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.settingsEraseConfirmBody(_eraseWord)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: l.settingsEraseConfirmHint(_eraseWord),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l.settingsResetCancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: color.error,
                    foregroundColor: color.onError,
                  ),
                  onPressed: matches
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: Text(l.settingsEraseButton),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await eraseAllData();
    if (!mounted) return;
    // The onboarding flag was cleared with everything else, so the tree comes
    // back on the welcome sheet -- exactly like a fresh install.
    restartApp();
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
