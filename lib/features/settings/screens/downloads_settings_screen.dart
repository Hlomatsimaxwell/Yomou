import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/backup/saf_directory_picker.dart';
import 'package:yomou/features/settings/providers/download_settings_provider.dart';
import 'package:yomou/features/settings/screens/manga_directories_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// Settings > Downloads: where chapters and pages are stored, the download
/// format preference and the cellular-network policy.
class DownloadsSettingsScreen extends ConsumerWidget {
  const DownloadsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(downloadSettingsProvider);
    final notifier = ref.read(downloadSettingsProvider.notifier);

    return Scaffold(
      appBar: SettingsAppBar(title: l.downloads),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _row(
            context: context,
            icon: RemixIcons.folder_open_line,
            title: l.dlsDirsTitle,
            subtitle: Text(l.dlsDirsCount(3 + s.customDirs.length)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MangaDirectoriesScreen(),
                ),
              );
            },
          ),
          _row(
            context: context,
            icon: RemixIcons.folder_line,
            title: l.dlsFolderTitle,
            subtitle: _resolvedPath(s.downloadsFolder, l.dlsNotSet),
            onTap: () => _showFolderPicker(context, l, s, notifier),
          ),
          _row(
            context: context,
            icon: RemixIcons.file_line,
            title: l.dlsFormatTitle,
            subtitle: Text(_formatLabel(l, s.preferredFormat)),
            onTap: () => _showFormatPicker(context, l, s, notifier),
          ),
          _row(
            context: context,
            icon: RemixIcons.signal_wifi_line,
            title: l.dlsNetworkTitle,
            subtitle: Text(_networkLabel(l, s.cellularNetwork)),
            onTap: () => _showNetworkPicker(context, l, s, notifier),
          ),
          _infoBlock(context, l),
          M3SectionHeader(title: l.dlsSectionSaving),
          _row(
            context: context,
            icon: RemixIcons.save_line,
            title: l.dlsSaveDirTitle,
            subtitle: _resolvedPath(s.defaultPageSaveDir, l.dlsNotSet),
            onTap: () => _pickPageSaveDir(context, notifier),
          ),
          SwitchListTile(
            title: Text(l.dlsAskDirTitle),
            subtitle: Text(l.dlsAskDirSubtitle),
            value: s.askDestinationEveryTime,
            onChanged: (_) => notifier.setAskDestinationEveryTime(
              !s.askDestinationEveryTime,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _row({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Icon(icon, size: 26),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: subtitle,
      ),
      trailing: Icon(
        RemixIcons.arrow_right_s_line,
        color: Theme.of(context).colorScheme.outline,
      ),
      onTap: onTap,
    );
  }

  Widget _infoBlock(BuildContext context, AppLocalizations l) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              RemixIcons.information_line,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.dlsInfoBody,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLabel(AppLocalizations l, String format) {
    switch (format) {
      case kFormatSingleCbz:
        return l.dlsFormatCbz;
      case kFormatMultipleCbz:
        return l.dlsFormatCbzs;
      default:
        return l.dlsFormatAuto;
    }
  }

  String _networkLabel(AppLocalizations l, String policy) {
    switch (policy) {
      case kNetworkAllow:
        return l.dlsNetworkAllow;
      case kNetworkDeny:
        return l.dlsNetworkDeny;
      default:
        return l.dlsNetworkAsk;
    }
  }

  /// Subtitle for rows that point at a real directory: shows the resolved
  /// file-system path (tree URIs are resolved natively), falling back to
  /// [fallback] while resolving or when the location can't be resolved.
  Widget _resolvedPath(String id, String fallback) {
    return FutureBuilder<String?>(
      future: resolveDownloadLocationPath(id),
      builder: (context, snapshot) {
        final path = snapshot.data;
        return Text(
          (path == null || path.isEmpty) ? fallback : path,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  /// Opens the system folder picker and stores the picked folder as the
  /// default destination for saved pages.
  Future<void> _pickPageSaveDir(
    BuildContext context,
    DownloadSettingsNotifier notifier,
  ) async {
    final uri = await pickBackupDirectory();
    if (uri == null || !context.mounted) return;
    final id = '$kFolderCustomPrefix$uri';
    await notifier.setDefaultPageSaveDir(id);
    // Keep saved pages out of the gallery's media scanner.
    await markDirAsNoMedia(id);
  }

  List<(String, String)> _folderOptions(AppLocalizations l, DownloadSettings s) {
    return [
      (kFolderChapters, l.dlsFolderChapters),
      (kFolderPublic, l.dlsFolderPublic),
      (kFolderDocuments, l.dlsFolderDocuments),
      for (final d in s.customDirs)
        ('$kFolderCustomPrefix${d.uri}', l.dlsFolderCustom(d.title)),
    ];
  }

  Future<void> _showFolderPicker(
    BuildContext context,
    AppLocalizations l,
    DownloadSettings s,
    DownloadSettingsNotifier notifier,
  ) {
    return _showPicker(
      context: context,
      l: l,
      title: l.dlsFolderTitle,
      options: _folderOptions(l, s),
      selected: s.downloadsFolder,
      onSelect: notifier.setDownloadsFolder,
    );
  }

  Future<void> _showFormatPicker(
    BuildContext context,
    AppLocalizations l,
    DownloadSettings s,
    DownloadSettingsNotifier notifier,
  ) {
    final options = [
      (kFormatAuto, l.dlsFormatAuto),
      (kFormatSingleCbz, l.dlsFormatCbz),
      (kFormatMultipleCbz, l.dlsFormatCbzs),
    ];
    return _showPicker(
      context: context,
      l: l,
      title: l.dlsFormatTitle,
      options: options,
      selected: s.preferredFormat,
      onSelect: notifier.setPreferredFormat,
    );
  }

  Future<void> _showNetworkPicker(
    BuildContext context,
    AppLocalizations l,
    DownloadSettings s,
    DownloadSettingsNotifier notifier,
  ) {
    final options = [
      (kNetworkAllow, l.dlsNetworkAllow),
      (kNetworkAsk, l.dlsNetworkAsk),
      (kNetworkDeny, l.dlsNetworkDeny),
    ];
    return _showPicker(
      context: context,
      l: l,
      title: l.dlsNetworkTitle,
      options: options,
      selected: s.cellularNetwork,
      onSelect: notifier.setCellularNetwork,
    );
  }

  /// Shared option-sheet used by every picker: a row per option with an
  /// accent check on the selected one, plus a bottom-right Cancel footer.
  Future<void> _showPicker({
    required BuildContext context,
    required AppLocalizations l,
    required String title,
    required List<(String, String)> options,
    required String selected,
    required Future<void> Function(String) onSelect,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showM3ModalSheet<String>(
      context,
      title: title,
      children: [
        for (final (id, label) in options)
          ListTile(
            title: Text(label),
            trailing: id == selected
                ? Icon(RemixIcons.check_line, color: cs.primary)
                : null,
            onTap: () => Navigator.pop(context, id),
          ),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l.cancel,
                style: TextStyle(color: cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await onSelect(picked);
  }
}