import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/changelog/changelog.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// Presents the "What's new" notes for [release].
///
/// Shown automatically the first launch after the version name changes, and on
/// demand from Settings -> About. A bottom sheet on a phone, a right-hand panel
/// on a wide window, matching the welcome sheet.
Future<void> showWhatsNewSheet(
  BuildContext context,
  ChangelogRelease release,
) {
  return showIosSheet<void>(
    context,
    isScrollControlled: true,
    builder: (_) => WhatsNewContent(release: release),
  );
}

class WhatsNewContent extends ConsumerWidget {
  const WhatsNewContent({super.key, required this.release});

  final ChangelogRelease release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = ref.watch(accentProvider);
    final sidePanel = usesWideLayout(context);

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.whatsNewVersionTitle(release.version),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (release.date != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            release.date!,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
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
            ),
            const SizedBox(height: 16),
            for (final section in release.sections) ...[
              _Section(section: section, accent: accent),
              const SizedBox(height: 18),
            ],
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  l.whatsNewGotIt,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section, required this.accent});

  final ChangelogSection section;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _sectionLabel(l, section.title),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: accent,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in section.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 10),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    _stripMarkdown(entry),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The changelog headings are English; show the reader a localized label for
/// the ones we know and fall back to the raw heading otherwise.
String _sectionLabel(AppLocalizations l, String title) {
  switch (title.toLowerCase()) {
    case 'added':
      return l.changelogAdded;
    case 'changed':
      return l.changelogChanged;
    case 'fixed':
      return l.changelogFixed;
    case 'removed':
      return l.changelogRemoved;
    case 'deprecated':
      return l.changelogDeprecated;
    case 'security':
      return l.changelogSecurity;
    case 'performance':
      return l.changelogPerformance;
    default:
      return title;
  }
}

/// Renders the tiny subset of Markdown the changelog uses: **bold**, *italic*
/// and `code` spans. Everything else is plain text, so links and other syntax
/// read as written rather than disappearing.
TextSpan _stripMarkdown(String source) {
  final spans = <TextSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
  var index = 0;
  for (final match in pattern.allMatches(source)) {
    if (match.start > index) {
      spans.add(TextSpan(text: source.substring(index, match.start)));
    }
    final bold = match.group(1);
    final italic = match.group(2);
    final code = match.group(3);
    if (bold != null) {
      spans.add(
        TextSpan(
          text: bold,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    } else if (italic != null) {
      spans.add(
        TextSpan(
          text: italic,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    } else if (code != null) {
      spans.add(
        TextSpan(
          text: code,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      );
    }
    index = match.end;
  }
  if (index < source.length) {
    spans.add(TextSpan(text: source.substring(index)));
  }
  return TextSpan(children: spans);
}
