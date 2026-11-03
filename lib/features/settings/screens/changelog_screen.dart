import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/changelog/changelog.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/features/whats_new/changelog_section_view.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// The whole release history, newest first, on one scrollable page.
///
/// Kotatsu-Redo renders its changelog as a full screen of Markdown rather than
/// a sheet for the running version only; this is the same shape, using the
/// parsed `CHANGELOG.md` the app already ships.
class ChangelogScreen extends ConsumerStatefulWidget {
  const ChangelogScreen({super.key});

  @override
  ConsumerState<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends ConsumerState<ChangelogScreen> {
  late final Future<List<ChangelogRelease>> _releases = loadChangelog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = ref.watch(accentProvider);
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: SettingsAppBar(title: l.aboutChangelog),
      body: CappedContentWidth(
        child: FutureBuilder<List<ChangelogRelease>>(
          future: _releases,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final releases = snapshot.data ?? const <ChangelogRelease>[];
            if (releases.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l.aboutNoChangelog,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: color.onSurfaceVariant),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: releases.length,
              separatorBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: color.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              itemBuilder: (context, index) => _ReleaseView(
                release: releases[index],
                accent: accent,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReleaseView extends StatelessWidget {
  const _ReleaseView({required this.release, required this.accent});

  final ChangelogRelease release;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          release.version,
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
        const SizedBox(height: 16),
        for (final section in release.sections) ...[
          ChangelogSectionView(section: section, accent: accent),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}
