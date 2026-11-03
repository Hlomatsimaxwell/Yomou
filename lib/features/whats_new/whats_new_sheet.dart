import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/changelog/changelog.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/features/whats_new/changelog_section_view.dart';
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
                    icon: const Icon(MdiIcons.close),
                    tooltip: l.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            for (final section in release.sections) ...[
              ChangelogSectionView(section: section, accent: accent),
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
