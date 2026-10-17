import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/widgets/kotatsu_icon.dart';
import 'package:yomou/features/settings/providers/storage_usage_provider.dart';
import 'package:yomou/features/settings/screens/data_cleanup_screen.dart';
import 'package:yomou/features/settings/screens/settings_screen.dart';
import 'package:yomou/features/settings/screens/storage_settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';
import 'package:yomou/widgets/storage_usage_bar.dart';

import 'test_fonts.dart';

/// The Storage and network pane: the usage block it opens with, the row that
/// hands back the space it counts, and the two rows that say what is allowed
/// to be fetched ahead of you.
///
/// Its order and its two groups are Kotatsu-Redo's `pref_network_storage.xml`
/// up to the point where that file asks for network features this app has not
/// built. The last four of its rows are deliberately absent rather than drawn
/// as rows that cannot be tapped.
///
/// Measurement is in Roboto, the font the app ships, for the same reason the
/// other settings panes' tests are: the framework's fallback draws every glyph
/// a full em wide and measures rows the device does not.
void main() {
  setUpAll(TestFonts.ensureLoaded);

  /// Five gigabytes of downloads, 108 of cached pages, 43 of stray temp files
  /// and 324 gigabytes still free -- each a whole number of the unit the
  /// legend formats it with, so the expected strings are exact.
  const usage = StorageUsage(
    savedManga: 5 * 1073741824,
    pagesCache: 108 * 1048576,
    otherCache: 43 * 1048576,
    available: 324 * 1073741824,
  );

  Widget pane({StorageUsage measured = usage}) {
    return ProviderScope(
      // The real one walks the device's filesystem, which a test has none of:
      // what is under test is the pane's shape and the strings it quotes.
      overrides: [
        storageUsageProvider.overrideWith((ref) async => measured),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(fontFamily: TestFonts.family),
        home: const SettingsPaneScope(child: StorageSettingsScreen()),
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1400, 4000),
    StorageUsage measured = usage,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(pane(measured: measured));
    await tester.pumpAndSettle();
  }

  /// The rows in the order they are laid out, usage bar and legend aside.
  List<String> rowTitles(WidgetTester tester) {
    return [
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        (tile.title! as Text).data!,
    ];
  }

  testWidgets('the rows run in the inspo order, under their own header',
      (tester) async {
    await pump(tester);

    expect(rowTitles(tester), const [
      'Data removal',
      'Content preloading',
      'Preload pages',
    ]);

    // The header is the one group break the pane needs: it names the block
    // above the first row, and draws no rule over itself because there is
    // nothing above it to separate from.
    final headers = tester.widgetList<M3SectionHeader>(find.byType(M3SectionHeader)).toList();
    expect(headers, hasLength(1));
    expect(headers.single.title, 'Storage usage');
    expect(headers.single.dividerAbove, isFalse);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the usage bar opens the pane, and counts in the inspo buckets',
      (tester) async {
    await pump(tester);

    final bar = tester.getRect(find.byType(StorageUsageBar));
    final header = tester.getRect(find.text('Storage usage'));
    final firstRow = tester.getRect(find.widgetWithText(ListTile, 'Data removal'));

    // The bar is what the header names, and the rows come after both.
    expect(header.bottom, lessThanOrEqualTo(bar.top));
    expect(bar.bottom, lessThanOrEqualTo(firstRow.top));

    // Size first, name second -- the order the inspo's own pattern writes
    // them in -- and all four buckets named even though only the filled ones
    // are drawn across the bar.
    for (final legend in const [
      '5.00 GB - Saved manga',
      '108.0 MB - Pages cache',
      '43.0 MB - Other cache',
      '324.00 GB - Available',
    ]) {
      expect(find.text(legend), findsOneWidget, reason: legend);
    }

    // The reference's own three wedge colours, then the container colour the
    // track is painted in -- which is what makes "Available" read as the part
    // of the bar nothing is filling. The shape of those three is pinned in
    // storage_usage_bar_test.dart; here it is enough that none of them is one
    // of the scheme's accents.
    final segments = tester
        .widget<StorageUsageBar>(find.byType(StorageUsageBar))
        .segments;
    final cs = Theme.of(tester.element(find.byType(StorageUsageBar))).colorScheme;
    expect(segments.map((s) => s.color), [
      StorageUsageBar.savedMangaColor,
      StorageUsageBar.pagesCacheColor,
      StorageUsageBar.otherCacheColor,
      cs.secondaryContainer,
    ]);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a bucket with nothing in it keeps its legend, not a wedge',
      (tester) async {
    await pump(
      tester,
      measured: const StorageUsage(
        savedManga: 5 * 1073741824,
        pagesCache: 0,
        otherCache: 0,
        available: 324 * 1073741824,
      ),
    );

    // The line still says how little there is, so the reader is not left
    // wondering whether the category was forgotten.
    expect(find.text('0 B - Pages cache'), findsOneWidget);
    expect(find.text('0 B - Other cache'), findsOneWidget);

    // Two wedges across the track rather than two of nothing between the
    // ones that matter. A wedge is the one thing in the bar painted by a
    // [ColoredBox]; the track is a [DecoratedBox] under it and the legend's
    // dots are [DecoratedBox]es of their own, so neither counts.
    final wedges = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(StorageUsageBar),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(wedges, hasLength(2));

    expect(tester.takeException(), isNull);
  });

  testWidgets('one rule starts the second group, 40 under the row above it',
      (tester) async {
    await pump(tester);

    final rules = tester.widgetList<Divider>(find.byType(Divider)).toList();
    expect(rules, hasLength(1));
    // 24 for the rule's own box plus the 8 of air a section header keeps
    // above and below its rule, so the line clears the rows on both sides.
    expect(rules.single.height, 40);
    expect(rules.single.thickness, 1);

    final rows = {
      for (final title in rowTitles(tester))
        title: tester.getRect(find.widgetWithText(ListTile, title)),
    };
    final rule = tester.getRect(find.byType(Divider));
    expect(rule.top, rows['Data removal']!.bottom);
    expect(rows['Content preloading']!.top - rows['Data removal']!.bottom, 40);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the rows keep the pane rhythm and carry no chevron',
      (tester) async {
    await pump(tester);

    for (final title in rowTitles(tester)) {
      expect(
        tester.getRect(find.widgetWithText(ListTile, title)).height,
        SettingsRows.rowHeight,
        reason: title,
      );
    }
    // A row that opens a screen or a sheet is a row, not a menu item: no
    // trailing arrow, the same as every other pane.
    expect(find.byIcon(MdiIcons.chevronRight), findsNothing);
    for (final title in const ['Data removal', 'Preload pages']) {
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, title)).trailing,
        isNull,
        reason: title,
      );
    }
    // And the one row that does carry a control still carries it, so the
    // empty trailing slots are not just the default.
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Content preloading'))
          .trailing,
      isA<Switch>(),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('each row leads with the inspo glyph for it', (tester) async {
    await pump(tester);

    Widget leading(String title) =>
        tester.widget<ListTile>(find.widgetWithText(ListTile, title)).leading!;

    for (final (title, name) in const [
      ('Data removal', 'ic_clear_all'),
      ('Content preloading', 'ic_download'),
      ('Preload pages', 'ic_book_page'),
    ]) {
      expect(leading(title), isA<KotatsuIcon>(), reason: title);
      expect((leading(title) as KotatsuIcon).name, name, reason: title);
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('the preload rows reach the settings they are named for',
      (tester) async {
    await pump(tester);

    // "Preload pages" is the reader's own policy, so the pane opens the same
    // three choices and quotes the one in force.
    expect(find.text('Only on Wi-Fi'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Preload pages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Never'));
    await tester.pumpAndSettle();
    expect(find.text('Never'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Content preloading'),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    final toggled = tester.widget<Switch>(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Content preloading'),
        matching: find.byType(Switch),
      ),
    );
    expect(toggled.value, isFalse);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a window with a pane opens data removal in it, and leaves back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageUsageProvider.overrideWith((ref) async => usage),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(fontFamily: TestFonts.family),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Storage and network'));
    await tester.pumpAndSettle();
    expect(find.byType(DataCleanupScreen), findsNothing);

    await tester.tap(find.text('Data removal'));
    await tester.pumpAndSettle();

    // The sub-screen is beside the list it came from, not over the top of it,
    // so the reader keeps their way out of this section.
    expect(find.byType(DataCleanupScreen), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    // What it holds: the cache rows the pane used to show inline.
    expect(find.text('Cache size'), findsOneWidget);
    expect(find.text('Cache staleness'), findsOneWidget);
    expect(find.text('Clear image cache'), findsOneWidget);

    // The arrow on the sub-screen's own bar leaves it, back to the category
    // it hangs off, still inside settings.
    await tester.tap(
      find.descendant(
        of: find.byType(DataCleanupScreen),
        matching: find.byIcon(MdiIcons.arrowLeft),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DataCleanupScreen), findsNothing);
    expect(find.text('Data removal'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
