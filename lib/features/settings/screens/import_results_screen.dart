import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/backup/tachiyomi_backup.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// Shows a per-manga summary right after a Tachiyomi/Mihon import: what got
/// imported (source + read position) and what was skipped and why.
class ImportResultsScreen extends StatelessWidget {
  const ImportResultsScreen({super.key, required this.result});

  final TachiyomiImportResult result;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: SettingsAppBar(title: l.importResultsTitle),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        children: [
          const SizedBox(height: 4),
          _SummaryHeader(result: result),
          const SizedBox(height: 8),
          if (result.mangas.isNotEmpty) ...[
            _SectionHeader(
              icon: RemixIcons.check_double_line,
              title: l.importResultsImportedSection,
              count: result.mangas.length,
              color: color.primary,
            ),
            for (final m in result.mangas) _ImportedTile(manga: m),
            const Divider(height: 20),
          ],
          if (result.skippedMangas.isNotEmpty) ...[
            _SectionHeader(
              icon: RemixIcons.error_warning_line,
              title: l.importResultsSkippedSection,
              count: result.skippedMangas.length,
              color: color.error,
            ),
            for (final s in result.skippedMangas) _SkippedTile(skipped: s),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.result});

  final TachiyomiImportResult result;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final allImported = result.skippedMangas.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark
            ? color.surfaceContainerHighest.withValues(alpha: 0.5)
            : color.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: allImported
                  ? color.primaryContainer
                  : color.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              allImported
                  ? RemixIcons.check_double_line
                  : RemixIcons.information_line,
              color: allImported
                  ? color.onPrimaryContainer
                  : color.onErrorContainer,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: allImported
                ? Text(l.importResultsAllImported)
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: l.importResultsImported(result.mangas.length),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: '  ·  '),
                        TextSpan(
                          text: l.importResultsNotImported(result.skipped),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(color: color.onSurface),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ImportedTile extends StatelessWidget {
  const _ImportedTile({required this.manga});

  final TachiyomiImportedManga manga;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme;
    final subtitle = manga.lastReadChapter > 0
        ? '${TachiyomiBackupCodec.sourceDisplayName(manga.sourceId)} · '
            '${l.importResultsReadTo(manga.lastReadChapter)}'
        : TachiyomiBackupCodec.sourceDisplayName(manga.sourceId);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Icon(
          RemixIcons.check_line,
          size: 22,
          color: color.primary,
        ),
      ),
      title: Text(
        manga.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: TextStyle(fontSize: 12.5, color: color.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _SkippedTile extends StatelessWidget {
  const _SkippedTile({required this.skipped});

  final TachiyomiSkippedManga skipped;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme;
    final source = skipped.sourceName;
    final reason = switch (skipped.reason) {
      TachiyomiSkippedReason.unsupportedSource => source != null &&
              source.isNotEmpty
          ? l.importResultsSkippedReasonSource(source)
          : l.importResultsSkippedReasonSourceFallback,
      _ => l.importResultsSkippedReasonId,
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Icon(
          RemixIcons.close_circle_line,
          size: 22,
          color: color.error,
        ),
      ),
      title: Text(
        (skipped.title ?? skipped.url ?? 'Unknown').toString(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          reason,
          style: TextStyle(fontSize: 12.5, color: color.onSurfaceVariant),
        ),
      ),
    );
  }
}