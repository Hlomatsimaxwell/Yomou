import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/features/settings/screens/reset_settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ResetSettingsScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every settings group', (tester) async {
    await _pump(tester);
    expect(find.byType(CheckboxListTile), findsNWidgets(6));
    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('the reset button stays disabled until a group is picked',
      (tester) async {
    await _pump(tester);
    final button = find.text('Reset selected');
    expect(button, findsOneWidget);
  });
}
