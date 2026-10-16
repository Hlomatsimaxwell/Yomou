import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/content_preferences/widgets/content_preferences_editor.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// Where the languages and formats picked on the welcome sheet are changed
/// afterwards.
///
/// The sheet itself is only presented on first launch, so these choices need a
/// home of their own -- otherwise picking "Manhwa" once is permanent.
class ContentPreferencesScreen extends ConsumerWidget {
  const ContentPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: SettingsAppBar(title: l.settingsContentPreferences),
      body: CappedContentWidth(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: ContentPreferencesEditor(introText: l.welcomeIntro),
        ),
      ),
    );
  }
}
