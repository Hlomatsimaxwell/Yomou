import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/widgets/yomou_chip.dart';
import 'package:yomou/features/onboarding/content_preferences_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// Localized name for a content language, falling back to the canonical name
/// for anything not covered by its own string.
String contentLanguageLabel(AppLocalizations l, String name) {
  switch (name) {
    case 'English':
      return l.langEnglish;
    case 'Spanish':
      return l.langSpanish;
    case 'Portuguese':
      return l.langPortuguese;
    case 'French':
      return l.langFrench;
    case 'Japanese':
      return l.langJapanese;
    case 'Korean':
      return l.langKorean;
    case 'Chinese':
      return l.langChinese;
    case 'Arabic':
      return l.langArabic;
    case 'Russian':
      return l.langRussian;
    case 'Italian':
      return l.langItalian;
    case 'German':
      return l.langGerman;
    case 'Indonesian':
      return l.langIndonesian;
  }
  return name;
}

/// Localized name for a content format.
String contentFormatLabel(AppLocalizations l, String format) {
  switch (format) {
    case 'Manga':
      return l.formatManga;
    case 'Manhwa':
      return l.formatManhwa;
    case 'Manhua':
      return l.formatManhua;
    case 'Novel':
      return l.formatNovel;
  }
  return format;
}

/// The two chip sections from the welcome sheet, shared with the content
/// preferences screen so the pickers cannot drift apart once the reader comes
/// back to change them.
///
/// Selections are written straight to [contentPreferencesProvider] on tap,
/// which persists them; there is no separate commit step.
class ContentPreferencesEditor extends ConsumerWidget {
  const ContentPreferencesEditor({
    super.key,
    required this.introText,
    this.accent,
  });

  /// Instructional paragraph shown above the sections.
  final String introText;
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final prefs = ref.watch(contentPreferencesProvider);
    final controller = ref.read(contentPreferencesProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          introText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        _SectionLabel(l.welcomeLanguages),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final language in kContentLanguages)
              YomouChip(
                label: contentLanguageLabel(l, language),
                accent: accent,
                selected: prefs.languages.contains(language),
                onTap: () => controller.toggleLanguage(language),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionLabel(l.welcomeType),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final format in kContentFormats)
              YomouChip(
                label: contentFormatLabel(l, format),
                accent: accent,
                selected: prefs.formats.contains(format),
                onTap: () => controller.toggleFormat(format),
              ),
          ],
        ),
      ],
    );
  }
}

/// The small section heading above each chip group.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
