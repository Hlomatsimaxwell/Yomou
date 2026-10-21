import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/kotatsu_icon.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_details.dart';
import 'package:yomou/features/source_management/widgets/manga_preview_pane.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

import 'isolated_database.dart';
import 'test_fonts.dart';

/// The wide-layout preview pane, held to the reference preview's shape.
///
/// The shape was rebuilt from a custom top bar into one card: the header row
/// carries the cover, the title column and the single close control; Read and
/// the break-out share the row directly beneath it; the tags follow as
/// outlined pills; the summary runs on with no caption over it. What this
/// pins is that geometry, and the two claims the rebuild makes about state:
/// the header never goes away -- not while the details load, not when the
/// source is gone -- so the close control is always reachable, and a source
/// that reports nothing still leaves a pane you can read and act on.
///
/// The details come from a seeded `source_cache` row rather than the network,
/// because a fresh row is a cache hit: the pane never fetches, so the test
/// controls exactly what "loaded" means.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedTestDatabase();
  setUpAll(TestFonts.ensureLoaded);

  /// The listing row's own title. The details below report a different one, so
  /// the header must show both: the detail endpoint's name as the title, and
  /// this one on the line beneath it.
  const listingTitle = 'Bachi-Gui (Weekly)';

  final details = MangaDetails(
    id: 'bachi-gui',
    title: 'Bachi-Gui',
    coverUrl: '',
    sourceId: 'mangadex',
    author: 'Shinichi Watanabe',
    description: 'A back-alley mahjong manga about reading people, not tiles.',
    tags: const ['Mahjong', 'Seinen'],
    // Both of these were carried by the header's old key-value table, which
    // the rebuild removed. Their absence here is the point, not an oversight.
    status: 'Ongoing',
    year: '2019',
  );

  Manga listing({String id = 'bachi-gui', String sourceId = 'mangadex'}) =>
      Manga(id: id, title: listingTitle, coverUrl: '', sourceId: sourceId);

  /// Writes the details the pane would otherwise have to fetch.
  Future<void> seedDetails(MangaDetails cached) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('source_cache', {
      'key': 'mangadex/details/${cached.id}',
      'json': jsonEncode(cached.toJson()),
      'fetchedAt': DateTime.now().toIso8601String(),
    });
  }

  /// The pane's width at the window this test pumps.
  ///
  /// The pane is no longer a fixed 340: it is the reference's 40% share of the
  /// window, clamped to 320-600. A 340-wide viewport is right at the foot of
  /// that range -- 40% of the window it stands in for would be 136, so it is
  /// the clamp, not the share, that is in force. The geometry below is the
  /// card's own, though, not the pane's, so the numbers hold at any width in
  /// the range; what the test needs is only to pump the pane at one of them.
  const paneWidth = 340.0;

  /// Pumps the pane alone, at the width the browse screen gives it.
  Future<AppLocalizations> pumpPane(WidgetTester tester, Manga manga) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(paneWidth, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(fontFamily: TestFonts.family),
          home: Scaffold(
            body: MangaPreviewPane(
              manga: manga,
              onRead: () {},
              onOpenFull: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    return AppLocalizations.of(tester.element(find.byType(MangaPreviewPane)));
  }

  /// Pumps until [done], or fails after a generous number of tries.
  ///
  /// The load reads a real SQLite file, whose futures complete on a real clock
  /// while a widget test body runs in fake time -- so each turn runs the wait
  /// in real time via `runAsync` and only then pumps. Pumping, not settling,
  /// is deliberate: the loading spinner is an indeterminate animation and
  /// `pumpAndSettle` would spin on it forever.
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    String because = '',
  }) async {
    for (var i = 0; i < 60 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(done(), isTrue, reason: because);
  }

  testWidgets('the loaded card runs cover, title, author, Read, tags, summary', (
    tester,
  ) async {
    await tester.runAsync(() => seedDetails(details));
    final l = await pumpPane(tester, listing());
    await pumpUntil(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
      because: 'the seeded details never loaded',
    );

    // Point 1: no top bar and no caption word -- the only way out is the one
    // close control, at the card's top-right corner.
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Preview'), findsNothing);
    expect(find.byIcon(MdiIcons.close), findsOneWidget);
    // The old header's fullscreen glyph is gone; the break-out now lives
    // beside Read as the reference's expand mark.
    expect(find.byIcon(MdiIcons.fullscreen), findsNothing);
    final closeRect = tester.getRect(find.byIcon(MdiIcons.close));
    expect(closeRect.right, greaterThan(300), reason: 'pinned to the right');
    expect(closeRect.top, lessThan(40), reason: 'pinned to the top');

    // Point 2: cover and title column share one row. The cover is the fixed
    // box inside the reference's own size range, rounded like the grid
    // renders its covers.
    final coverRect = tester.getRect(find.byType(CachedMangaImage));
    expect(coverRect.width, 120);
    expect(coverRect.height, 172);
    final coverClip = tester.widget<ClipRRect>(
      find
          .ancestor(
            of: find.byType(CachedMangaImage),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(coverClip.borderRadius, BorderRadius.circular(16));

    final title = tester.widget<Text>(find.text(details.title));
    expect(title.style!.fontSize, 24);
    expect(title.style!.fontWeight, FontWeight.w700);
    expect(title.maxLines, 5);
    final titleRect = tester.getRect(find.text(details.title));
    expect(titleRect.left, greaterThan(coverRect.right));

    // The second line carries the other name the two endpoints disagree on,
    // and vanishes when they agree -- here they do not.
    final aka = tester.widget<Text>(find.text(listingTitle));
    expect(aka.style!.fontSize, 14);
    expect(aka.maxLines, 3);
    // Unset weight reads as regular, which is what the line must be.
    expect(aka.style!.fontWeight ?? FontWeight.w400, FontWeight.w400);
    final akaRect = tester.getRect(find.text(listingTitle));
    expect(akaRect.top, greaterThan(titleRect.top));

    // Author is direct text at the same size -- and with no label in front of
    // it, and no State or Year rows below it.
    final author = tester.widget<Text>(find.text(details.author));
    expect(author.style!.fontSize, 14);
    expect(author.style!.fontWeight, FontWeight.w700);
    expect(find.text(l.detailAuthor), findsNothing);
    expect(find.text(l.detailState), findsNothing);
    expect(find.text(details.year), findsNothing);

    // Point 3: Read sits directly under the header, filled rather than
    // outlined, and carrying no leading book icon.
    final read = find.widgetWithText(FilledButton, l.readAction);
    expect(read, findsOneWidget);
    expect(find.descendant(of: read, matching: find.byType(Icon)), findsNothing);
    final readRect = tester.getRect(read);
    expect(
      readRect.top - coverRect.bottom,
      closeTo(16, 1),
      reason: 'one margin of air under the header',
    );
    final readButton = tester.widget<FilledButton>(read);
    final shape = readButton.style!.shape!.resolve(const <WidgetState>{});
    expect(shape, isA<RoundedRectangleBorder>());
    expect(
      (shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(20),
    );
    expect(
      readButton.style!.minimumSize!.resolve(const <WidgetState>{}),
      const Size.fromHeight(44),
    );

    // The break-out shares that row: the reference's 18px expand glyph,
    // centred on the button.
    final expand = find.byType(KotatsuIcon);
    expect(expand, findsOneWidget);
    expect(tester.widget<KotatsuIcon>(expand).size, 18);
    expect(tester.widget<KotatsuIcon>(expand).name, 'ic_expand');
    expect(find.byTooltip(l.openFullDetails), findsOneWidget);
    final expandRect = tester.getRect(expand);
    expect(expandRect.left, greaterThan(readRect.right - 1));
    expect(expandRect.center.dy, closeTo(readRect.center.dy, 1));

    // Point 4: the tags follow Read as hairline pills, not filled chips.
    final wrap = find.byType(Wrap);
    expect(wrap, findsOneWidget);
    final chips =
        tester
            .widgetList<Container>(
              find.descendant(of: wrap, matching: find.byType(Container)),
            )
            .toList();
    expect(chips, hasLength(details.tags.length));
    for (final chip in chips) {
      final deco = chip.decoration! as BoxDecoration;
      expect(deco.borderRadius, BorderRadius.circular(10));
      expect(deco.border!.top.width, 1);
      expect(chip.padding, const EdgeInsets.symmetric(horizontal: 10, vertical: 4));
    }
    for (final tag in details.tags) {
      expect(tester.widget<Text>(find.text(tag)).style!.fontSize, 11);
    }
    final wrapRect = tester.getRect(wrap);
    expect(
      wrapRect.top - readRect.bottom,
      closeTo(16, 1),
      reason: 'the pills follow Read, not the header',
    );

    // Point 5: the summary starts right under the pills with one small gap,
    // and nothing captions it.
    expect(find.text(l.description), findsNothing);
    final summary = find.text(details.description);
    expect(summary, findsOneWidget);
    expect(tester.widget<Text>(summary).style!.fontSize, 13);
    expect(
      tester.getRect(summary).top - wrapRect.bottom,
      closeTo(12, 1),
      reason: 'one small gap under the pills',
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the close control and the header are up before the load settles', (
    tester,
  ) async {
    // Nothing seeded: the pane has to fetch. A fetch started in a widget
    // test's fake time never settles -- dio does not complete under the test
    // framework's mock HttpClient -- so this pins the loading frame itself,
    // and the settled card comes from the seeded tests around it.
    final l = await pumpPane(tester, listing(id: 'not-in-cache'));

    // First frame: the header is already up, spinner below it, and the
    // controls that do not depend on the request are already there.
    expect(find.byIcon(MdiIcons.close), findsOneWidget);
    expect(find.text(listingTitle), findsOneWidget);
    expect(find.text(l.readAction), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a source that reports no author, tags or summary still leaves a card', (
    tester,
  ) async {
    // Details that answer the request with almost nothing: no author, no
    // tags, no summary -- what a thin source actually reports.
    final sparse = const MangaDetails(
      id: 'sparse-1',
      title: 'Sparse',
      coverUrl: '',
      sourceId: 'mangadex',
    );
    await tester.runAsync(() => seedDetails(sparse));
    final l = await pumpPane(
      tester,
      Manga(
        id: 'sparse-1',
        title: 'Sparse (Weekly)',
        coverUrl: '',
        sourceId: 'mangadex',
        // The listing row's own tags fill in for the missing ones.
        tags: const ['Action', 'Comedy'],
      ),
    );
    await pumpUntil(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
      because: 'the seeded details never loaded',
    );

    // Read stays usable and the summary says there is none, rather than
    // collapsing the body -- and an unreported author is a hidden line, not
    // a placeholder word.
    expect(find.widgetWithText(FilledButton, l.readAction), findsOneWidget);
    expect(find.text(l.noDescription), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Comedy'), findsOneWidget);
    expect(find.text(l.unknown), findsNothing);
    expect(find.byIcon(MdiIcons.close), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a manga whose source is gone says so, and stays closable', (
    tester,
  ) async {
    final l = await pumpPane(
      tester,
      listing(id: 'x', sourceId: 'retired-scanlations'),
    );
    await tester.pump();

    // Retrying cannot fix an uninstalled source, so the card offers the
    // empty state rather than a retry button -- and the close control and
    // the header the grid already showed are still there.
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text(l.previewSourceMissing), findsOneWidget);
    expect(find.byIcon(MdiIcons.close), findsOneWidget);
    expect(find.text(listingTitle), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text(l.retry), findsNothing);

    expect(tester.takeException(), isNull);
  });
}
