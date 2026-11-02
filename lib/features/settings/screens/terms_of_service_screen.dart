import 'package:flutter/material.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// Terms of service for Yomou.
///
/// Hosted copy (for Google Play Console): see `docs/terms_of_service.html`.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: SettingsAppBar(title: l.termsOfService, contentMargin: 24),
      body: CappedContentWidth(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          children: [
            _P(l.termsOfServiceBody),
          ],
        ),
      ),
    );
  }
}

class _P extends StatelessWidget {
  const _P(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
    );
  }
}
