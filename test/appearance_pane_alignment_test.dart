import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/widgets/kotatsu_icon.dart';
import 'package:yomou/features/settings/screens/appearance_settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// The appearance pane has one vertical guide: its title, its section labels,
/// its scheme cards and the leading icon of every row all start on the same
/// line. The parts are inset by different amounts to get there -- the list
/// carries 8, a `ListTile` and a section header add their own 16, and a scheme
/// card adds 8 twice over -- so the equality is what is worth pinning down
/// rather than any one of those numbers.
///
/// [pane] renders the screen the way the two-pane layout does, with the pane
/// scope set, because that is the only arrangement where the title is laid out
/// against the pane rather than against the screen.
void main() {
  Widget pane() {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsPaneScope(child: AppearanceSettingsScreen()),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, {Size size = const Size(1200, 4000)}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(pane());
    await tester.pumpAndSettle();
  }

  testWidgets('the title, the section labels and the row icons share a guide',
      (tester) async {
    await pump(tester);

    // The scrolling column the rows sit in. Its own left edge is the pane's
    // content box; the 24 guide is that plus the 8 the list contributes.
    final column = find.byType(ListView).first;
    final guide = tester.getTopLeft(column).dx + 24;

    final title = tester.getTopLeft(find.text('Appearance')).dx;
    final header = tester.getTopLeft(find.text('Color Scheme')).dx;
    final rowIcon = tester.getTopLeft(
      find.byWidgetPredicate(
        (w) => w is KotatsuIcon && w.name == 'ic_theme_mode',
      ),
    ).dx;

    expect(title, guide, reason: 'the pane title');
    expect(header, guide, reason: 'a section label');
    expect(rowIcon, guide, reason: 'a row leading icon');

    // The first scheme card opens on the same line. Only its own contents are
    // reachable from here -- the card is a private widget -- so this reads the
    // gap between the guide and the "Abc" the card draws inset at its top left.
    final abcs = tester.getTopLeft(find.text('Abc').first).dx;
    expect(abcs, greaterThan(guide));
    expect(abcs, lessThan(guide + 16), reason: 'inside the card at the guide');

    expect(tester.takeException(), isNull);
  });

  testWidgets('the pane title is a section-sized accent label', (tester) async {
    await pump(tester);

    final text = tester.widget<Text>(find.text('Appearance'));
    final style = text.style!;
    expect(style.fontSize, 14);
    expect(style.fontWeight, FontWeight.w600);

    final cs = Theme.of(
      tester.element(find.byType(AppearanceSettingsScreen)),
    ).colorScheme;
    expect(style.color, cs.primary);
  });

  testWidgets('the grid size row reads its name and value as two ends of one line',
      (tester) async {
    await pump(tester);

    // The setting keeps its own label instead of one interpolated string.
    expect(find.text('Grid size'), findsOneWidget);
    expect(find.text('Grid size: 100%'), findsNothing);
    expect(find.text('100%'), findsOneWidget);

    // Name and value share a baseline; the slider is the line under them.
    final name = tester.getCenter(find.text('Grid size'));
    final value = tester.getCenter(find.text('100%'));
    expect((name.dy - value.dy).abs(), lessThan(2));
    expect(name.dx, lessThan(value.dx));

    final slider = tester.getCenter(find.byType(Slider));
    expect(slider.dy, greaterThan(name.dy));
  });
}
