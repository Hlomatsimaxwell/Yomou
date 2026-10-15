import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';

import 'test_fonts.dart';

/// The two marks that sit in a cover's top corners.
///
/// The favourite heart used to be a hardcoded red circle, and History drew a
/// second copy of it inline from the row's own flag. Both badges are now
/// shared, read their providers, wear the theme's tonal discs the way the
/// reading-progress ring does, and animate in and out. They also used to share
/// one corner, where the heart - opaque, the same size, painted after - hid the
/// download mark on every title that was both downloaded and favourited.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestFonts.ensureLoaded);

  const id = 'manga-1';

  Widget host(Object key, List<Override> overrides, Widget child) {
    SharedPreferences.setMockInitialValues({});
    return ProviderScope(
      // A fresh scope per state: reusing the element would keep the old
      // override, and the badge would never see the toggle.
      key: ValueKey(key),
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(body: Stack(children: [child])),
      ),
    );
  }

  Widget heart(
    bool on, {
    Alignment alignment = Alignment.topRight,
    double inset = 6,
  }) {
    return host(
      'heart-$on',
      [
        favoritesProvider.overrideWith(
          (ref) async => on
              ? [Manga(id: id, title: 'T', coverUrl: '', sourceId: '0')]
              : <Manga>[],
        ),
      ],
      FavoriteBadge(mangaId: id, alignment: alignment, inset: inset),
    );
  }

  Widget download(
    bool on, {
    Alignment alignment = Alignment.topLeft,
    double inset = 6,
  }) {
    return host(
      'download-$on',
      [
        downloadedMangasProvider.overrideWith(
          (ref) async => on ? {id} : <String>{},
        ),
      ],
      DownloadedMangaBadge(mangaId: id, alignment: alignment, inset: inset),
    );
  }

  ColorScheme schemeOf(WidgetTester tester, Type badge) =>
      Theme.of(tester.element(find.byType(badge))).colorScheme;

  Color discColor(WidgetTester tester, Type badge) {
    final disc = tester.widget<Container>(
      find.descendant(of: find.byType(badge), matching: find.byType(Container)),
    );
    return (disc.decoration as BoxDecoration).color!;
  }

  Positioned placed(WidgetTester tester) =>
      tester.widget<Positioned>(find.byType(Positioned));

  testWidgets('the heart wears the theme tonal disc, not a hardcoded red', (
    tester,
  ) async {
    await tester.pumpWidget(heart(true));
    await tester.pump();

    final scheme = schemeOf(tester, FavoriteBadge);
    expect(discColor(tester, FavoriteBadge), scheme.tertiaryContainer);

    final glyph = tester.widget<Icon>(find.byIcon(RemixIcons.heart_3_fill));
    expect(glyph.color, scheme.onTertiaryContainer);
    expect(
      glyph.color,
      isNot(Colors.redAccent),
      reason: 'the disc is tinted per indicator, like the progress ring',
    );
  });

  testWidgets('the download mark wears its own tonal disc', (tester) async {
    await tester.pumpWidget(download(true));
    await tester.pump();

    final scheme = schemeOf(tester, DownloadedMangaBadge);
    expect(discColor(tester, DownloadedMangaBadge), scheme.primaryContainer);
    expect(discColor(tester, DownloadedMangaBadge), isNot(Colors.black54));

    final glyph = tester.widget<Icon>(find.byIcon(RemixIcons.sd_card_line));
    expect(glyph.color, scheme.onPrimaryContainer);
    expect(
      discColor(tester, DownloadedMangaBadge),
      isNot(scheme.tertiaryContainer),
      reason: 'two marks on one cover have to stay two marks',
    );
  });

  testWidgets('the heart waits, hidden, until the title is favourited', (
    tester,
  ) async {
    await tester.pumpWidget(heart(false));
    await tester.pump();

    // Mounted but scaled away, so favouriting animates instead of popping.
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 0);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    await tester.pumpWidget(heart(true));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
  });

  testWidgets('the download mark waits, hidden, until a chapter is saved', (
    tester,
  ) async {
    await tester.pumpWidget(download(false));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 0);

    await tester.pumpWidget(download(true));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('both badges pin to the corner they are given', (tester) async {
    await tester.pumpWidget(
      heart(true, alignment: Alignment.bottomRight, inset: 12),
    );
    await tester.pump();
    var box = placed(tester);
    expect(box.right, 12);
    expect(box.bottom, 12);
    expect(box.left, isNull);
    expect(box.top, isNull);

    await tester.pumpWidget(
      download(true, alignment: Alignment.topLeft, inset: 8),
    );
    await tester.pump();
    box = placed(tester);
    expect(box.left, 8);
    expect(box.top, 8);
    expect(box.right, isNull);
    expect(box.bottom, isNull);
  });

  testWidgets('the two default corners do not overlap', (tester) async {
    // The regression this guards: both badges defaulted to the top-right, so a
    // title that was downloaded and favourited showed only the heart.
    SharedPreferences.setMockInitialValues({});
    final overrides = [
      favoritesProvider.overrideWith(
        (ref) async => [Manga(id: id, title: 'T', coverUrl: '', sourceId: '0')],
      ),
      downloadedMangasProvider.overrideWith((ref) async => {id}),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FavoriteBadge(mangaId: id),
                DownloadedMangaBadge(mangaId: id),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boxes = tester.widgetList<Positioned>(find.byType(Positioned));
    expect(boxes, hasLength(2));
    final heartBox = boxes.first;
    final downloadBox = boxes.last;

    expect(heartBox.right, isNotNull, reason: 'the heart keeps the top-right');
    expect(heartBox.left, isNull);
    expect(
      downloadBox.left,
      isNotNull,
      reason: 'the download mark takes the free corner',
    );
    expect(downloadBox.right, isNull);
    expect(downloadBox.top, heartBox.top);
  });
}
