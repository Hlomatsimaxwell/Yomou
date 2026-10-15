import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';

import 'test_fonts.dart';

/// The favourite heart that sits on a manga cover.
///
/// It used to be a hardcoded red circle, drawn inline by the History card, and
/// only there. It is now the one shared badge every grid uses, wearing the
/// theme's tonal disc the way the reading-progress ring in the opposite corner
/// does, and reading the favourites provider so that a title unfavourited on
/// another screen cannot leave a stale heart behind.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestFonts.ensureLoaded);

  const id = 'manga-1';

  Widget host({
    required bool favorited,
    Alignment alignment = Alignment.topRight,
    double inset = 6,
  }) {
    SharedPreferences.setMockInitialValues({});
    return ProviderScope(
      // A fresh scope per state: reusing the element would keep the old
      // override, and the badge would never see the toggle.
      key: ValueKey(favorited),
      overrides: [
        favoritesProvider.overrideWith(
          (ref) async => favorited
              ? [Manga(id: id, title: 'T', coverUrl: '', sourceId: '0')]
              : <Manga>[],
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FavoriteBadge(mangaId: id, alignment: alignment, inset: inset),
            ],
          ),
        ),
      ),
    );
  }

  ColorScheme schemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(FavoriteBadge))).colorScheme;

  testWidgets('wears the theme tonal disc, not a hardcoded red', (tester) async {
    await tester.pumpWidget(host(favorited: true));
    await tester.pump();

    final scheme = schemeOf(tester);
    final disc = tester.widget<Container>(
      find.descendant(
        of: find.byType(FavoriteBadge),
        matching: find.byType(Container),
      ),
    );
    expect((disc.decoration as BoxDecoration).color, scheme.tertiaryContainer);

    final heart = tester.widget<Icon>(find.byIcon(RemixIcons.heart_3_fill));
    expect(heart.color, scheme.onTertiaryContainer);
    expect(
      heart.color,
      isNot(Colors.redAccent),
      reason: 'the disc is tinted per indicator, like the progress ring',
    );
  });

  testWidgets('waits, hidden, until the title is favourited', (tester) async {
    await tester.pumpWidget(host(favorited: false));
    await tester.pump();

    // Mounted but scaled away, so favouriting animates instead of popping.
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 0);
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0);

    await tester.pumpWidget(host(favorited: true));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('pins to the corner it is given', (tester) async {
    final topLeft = host(favorited: true, alignment: Alignment.topLeft);
    await tester.pumpWidget(topLeft);
    await tester.pump();

    var box = tester.widget<Positioned>(find.byType(Positioned));
    expect(box.left, 6);
    expect(box.top, 6);
    expect(box.right, isNull);
    expect(box.bottom, isNull);

    await tester.pumpWidget(
      host(favorited: true, alignment: Alignment.bottomRight, inset: 12),
    );
    await tester.pump();
    box = tester.widget<Positioned>(find.byType(Positioned));
    expect(box.right, 12);
    expect(box.bottom, 12);
    expect(box.left, isNull);
    expect(box.top, isNull);
  });
}
