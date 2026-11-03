import 'package:flutter/material.dart';
import 'package:yomou/core/changelog/changelog.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// One release section ("Added", "Fixed", ...) with its bullet list.
///
/// Shared by the What's new sheet and the full Changelog screen so the two
/// cannot render the same release differently.
class ChangelogSectionView extends StatelessWidget {
  const ChangelogSectionView({
    super.key,
    required this.section,
    required this.accent,
  });

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
