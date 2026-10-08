import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/backup/backup_restore.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/onboarding/content_preferences_editor.dart';
import 'package:yomou/features/onboarding/content_preferences_provider.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/features/settings/screens/import_results_screen.dart';
import 'package:yomou/features/settings/screens/manga_directories_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// Presents the welcome sheet.
///
/// On a phone it rises from the bottom; on a tablet or desktop window it comes
/// in as a panel on the right edge instead. A bottom sheet spanning a wide
/// window leaves the reader staring at a strip of content across a very wide
/// row of chips, and the right panel keeps the app visible beside it.
///
/// On first launch [isDismissible] is false: the scrim and the drag gesture
/// are both disabled, so the reader cannot reach the home screen without
/// either saving their choices or skipping them through the button. From
/// settings the same sheet comes back dismissible.
Future<void> showWelcomeSheet(
  BuildContext context, {
  required bool isDismissible,
}) {
  return showIosSheet<void>(
    context,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    isScrollControlled: true,
    builder: (sheetContext) => const WelcomeSheetContent(),
  );
}

class WelcomeSheetContent extends ConsumerWidget {
  const WelcomeSheetContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = ref.watch(accentProvider);
    // Wide windows present this as a panel on the right edge; the phone shape
    // is a bottom sheet. Same content, same behaviour, different silhouette.
    final sidePanel = usesWideLayout(context);

    final header = Row(
      children: [
        Icon(RemixIcons.user_3_line, size: 22, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l.welcomeTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (sidePanel)
          IconButton(
            icon: const Icon(RemixIcons.close_line),
            tooltip: l.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
      ],
    );

    final actions = SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _QuickAction(
            icon: RemixIcons.download_2_line,
            label: l.welcomeRestoreBackup,
            onTap: () => _restoreFromBackup(context, ref),
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: RemixIcons.restart_line,
            label: l.welcomeLoginSync,
            // No account system exists yet. A button that led nowhere would be
            // worse than one that says so.
            comingSoonLabel: l.welcomeComingSoon,
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: RemixIcons.folder_2_line,
            label: l.welcomeLocalDirs,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MangaDirectoriesScreen()),
            ),
          ),
        ],
      ),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        const SizedBox(height: 16),
        actions,
        const SizedBox(height: 20),
        ContentPreferencesEditor(introText: l.welcomeIntro, accent: accent),
      ],
    );

    final startButton = SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () async {
          await markWelcomeCompleted();
          if (context.mounted) Navigator.of(context).pop();
        },
        child: Text(
          l.welcomeStart,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );

    // One column in both shapes. The panel hugs this content rather than
    // filling the window, so there is no pinned footer to build -- the action
    // simply follows the sections it belongs with.
    return SafeArea(
      top: !sidePanel,
      bottom: true,
      child: SingleChildScrollView(
        padding: sidePanel
            ? const EdgeInsets.fromLTRB(24, 8, 24, 24)
            : const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            body,
            const SizedBox(height: 24),
            startButton,
          ],
        ),
      ),
    );
  }

  /// Opens the picker and applies whatever the picked file turns out to be.
  ///
  /// The reader is never asked which format their backup is: a Yomou `.json`
  /// and a Mihon `.json` are both just "a backup file" to the person holding
  /// it, so [BackupRestore] sniffs the contents instead.
  Future<void> _restoreFromBackup(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final file = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'tachibk', 'gz'],
      withData: true,
    );
    if (file == null) return;

    try {
      final picked = file.files.single;
      final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();
      final result = await BackupRestore.restore(bytes);

      if (!context.mounted) return;
      bumpHistoryRevision(ref);
      bumpFavoritesRevision(ref);

      final messenger = ScaffoldMessenger.of(context);
      switch (result.format) {
        case BackupFormat.yomou:
          final restored = result.yomou!;
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                restored.isEmpty
                    ? l.backupRestoreNone
                    : restored.skippedNewer > 0
                    ? '${l.backupRestoreDone(restored.restored)} · '
                          '${l.backupRestoreKeptNewer(restored.skippedNewer)}'
                    : l.backupRestoreDone(restored.restored),
              ),
            ),
          );
        case BackupFormat.tachiyomi:
          final parsed = result.tachiyomi!;
          if (parsed.mangas.isEmpty && parsed.skipped == 0) {
            messenger.showSnackBar(
              SnackBar(content: Text(l.tachiyomiImportNone)),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ImportResultsScreen(result: parsed),
            ),
          );
      }
    } on FormatException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.tachiyomiImportInvalid)));
    }
  }
}

/// One of the outlined shortcuts along the top of the sheet.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.comingSoonLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// When set, the button is disabled and shows this tag beside its label
  /// instead of responding to a tap.
  final String? comingSoonLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = comingSoonLabel == null ? false : onTap == null;
    final foreground = disabled
        ? theme.textTheme.labelLarge?.color?.withValues(alpha: 0.38)
        : theme.textTheme.labelLarge?.color;

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (disabled) ...[
                const SizedBox(width: 6),
                Text(
                  comingSoonLabel!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
