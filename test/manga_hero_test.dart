import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/widgets/manga_hero.dart';

/// The cover flight is only as good as the tag on both ends of it. These pin
/// the two properties the grids and the detail screen rely on: the same title
/// always names the same tag, and two different titles never share one.
void main() {
  test('the tag is stable for a title and unique across sources', () {
    expect(
      mangaCoverHeroTag(sourceId: '1', mangaId: 'a'),
      mangaCoverHeroTag(sourceId: '1', mangaId: 'a'),
    );
    // Two sources listing the same id must not collide, or the flight would
    // start from the wrong grid.
    expect(
      mangaCoverHeroTag(sourceId: '1', mangaId: 'a'),
      isNot(mangaCoverHeroTag(sourceId: '2', mangaId: 'a')),
    );
    // A title with no known source still gets its own tag.
    expect(
      mangaCoverHeroTag(sourceId: null, mangaId: 'a'),
      isNot(mangaCoverHeroTag(sourceId: '1', mangaId: 'a')),
    );
    expect(
      mangaCoverHeroTag(sourceId: '1', mangaId: 'a'),
      isNot(mangaCoverHeroTag(sourceId: '1', mangaId: 'b')),
    );
  });

  testWidgets('a tag wraps the cover in a Hero, and no tag leaves it bare',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MangaCoverHero(tag: 'manga-cover:1:a', child: Text('cover')),
        ),
      ),
    );
    expect(find.byType(Hero), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MangaCoverHero(tag: null, child: Text('cover'))),
      ),
    );
    expect(find.byType(Hero), findsNothing);
    expect(find.text('cover'), findsOneWidget);
  });
}
