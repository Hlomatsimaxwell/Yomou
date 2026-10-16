import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/theme/amoled.dart';
import 'package:yomou/features/settings/screens/appearance_settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// "Black" (AMOLED) is a switch on one screen and a tone table everywhere
/// else. These hold both halves: that the row is offered only where it can do
/// something, and that the helper the swept call sites use answers black only
/// when the reader asked for it.
void main() {
  Widget host({required Brightness brightness}) {
    return ProviderScope(
      child: MaterialApp(
        theme: brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppearanceSettingsScreen(),
      ),
    );
  }

  testWidgets('Black is offered only against a dark background, and toggles',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Light mode: the row is absent, because a switch that cannot change the
    // background it is sitting on reads as broken.
    await tester.pumpWidget(host(brightness: Brightness.light));
    await tester.pumpAndSettle();
    expect(find.text('Black'), findsNothing);

    await tester.pumpWidget(host(brightness: Brightness.dark));
    await tester.pumpAndSettle();
    final row = find.widgetWithText(SwitchListTile, 'Black');
    expect(row, findsOneWidget);
    expect(
      find.text('Uses less power on AMOLED screens'),
      findsOneWidget,
    );
    expect(tester.widget<SwitchListTile>(row).value, isFalse);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(row).value, isTrue);

    expect(tester.takeException(), isNull);
  });

  testWidgets('amoled() only blackens a tone under Black mode', (tester) async {
    // The two duties of the helper: hand the tone back untouched whenever the
    // setting is off, and -- because a widget can be pumped under a theme that
    // carries no AmoledMode at all, as a test or a preview does -- never throw
    // for the want of the extension.
    var pump = 0;
    Future<Color> toneUnder(ThemeData theme) async {
      Color? painted;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<int>(pump++),
          theme: theme,
          home: Builder(
            builder: (context) {
              painted = amoled(context, 0xFF2C2C2E);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return painted!;
    }

    expect(await toneUnder(ThemeData.dark()), const Color(0xFF2C2C2E));
    expect(
      await toneUnder(
        ThemeData.dark().copyWith(
          extensions: const <ThemeExtension<dynamic>>[
            AmoledMode(enabled: false),
          ],
        ),
      ),
      const Color(0xFF2C2C2E),
    );
    expect(
      await toneUnder(
        ThemeData.dark().copyWith(
          extensions: const <ThemeExtension<dynamic>>[
            AmoledMode(enabled: true),
          ],
        ),
      ),
      Colors.black,
    );
  });
}
