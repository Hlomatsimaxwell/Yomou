import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';

/// The detail header's cover was a fixed 125x175 at every width, then reduced
/// to a smaller footprint so the title and metadata beside it keep their room.
/// The phone lands on a 110px floor, a wide pane grows to a larger cover, and
/// a 200px ceiling holds so a large monitor does not turn the header into a
/// poster.
///
/// These pin the ends of that change: the floor, the growth, the ceiling, and
/// that the cover never reshapes as it grows.
void main() {
  /// The width the header section is actually given, which is what the cover is
  /// measured against.
  ///
  /// On a wide layout it is one pane of the split first -- the screen is 5/11 of
  /// the width the window gave the app, because the other 6/11 belongs to the
  /// chapter list beside it -- and only then does the section's own
  /// `EdgeInsets.symmetric(horizontal: 16)` come off each side.
  double columnWidth(double screenWidth) =>
      (screenWidth >= 840 ? screenWidth * 5 / 11 : screenWidth) - 32;

  /// The gap between the cover and the title block, which the cover may not eat.
  const double gap = 16;

  test('a phone gets the smaller cover the redesign asks for', () {
    // 360 is the narrowest phone this app is used on, and 328 is what its
    // header section is given. The floor is 110 wide.
    expect(columnWidth(360), 328.0);
    expect(mangaDetailCoverWidth(328.0), 110.0);
  });

  test('a phone in any other width is not made smaller or larger by mistake', () {
    // A 320px phone has a narrower column than the 328 the share was solved
    // against, so it has to be held at the floor rather than shrink.
    expect(mangaDetailCoverWidth(288.0), 110.0);
    // A large-font phone in landscape, and a small tablet in portrait: both are
    // wide layouts, so both get a real cover rather than the phone's.
    expect(mangaDetailCoverWidth(740.0), greaterThan(110.0));
  });

  test('a desktop pane gets a cover worth looking at', () {
    // 1245 is the app's width inside a 1325px window with the 80px nav rail
    // taken off -- the size this was reported against.
    final column = columnWidth(1245);
    final cover = mangaDetailCoverWidth(column);

    // Around 170 against the old 125: bigger than the phone, but deliberately
    // smaller than the old poster-sized ceiling so the metadata keeps its room.
    expect(cover, greaterThan(160.0));
    expect(cover, lessThan(215.0));
    // And the pane it left over is still wide enough for a title and a
    // metadata line rather than being a sliver beside a poster.
    expect(column - cover - gap, greaterThan(280.0));
  });

  test('the cover stops growing on a large monitor', () {
    for (final width in [1536.0, 1920.0, 2560.0, 3440.0]) {
      expect(
        mangaDetailCoverWidth(columnWidth(width)),
        200.0,
        reason: 'a ${width}px window should cap the cover, not fill the pane',
      );
    }
  });

  test('growing the cover does not reshape it', () {
    // 125:175 is what the fixed cover used, and a cover that grew in width while
    // keeping its height would have been squashed.
    for (final width in [125.0, 203.0, 240.0]) {
      expect(mangaDetailCoverHeight(width) / width, closeTo(175 / 125, 0.0001));
    }
    // The old pair is still one of the answers.
    expect(mangaDetailCoverHeight(125.0), 175.0);
  });

  test('the cover never gets narrower as the window widens', () {
    // Swept per layout, not across the 840px switch: the switch is where the
    // section stops being the whole screen and becomes one pane of a 5:6 split,
    // so the column it was given drops from 808 to 367 and the cover with it.
    // That is the layout changing, not the cover retreating -- and everything
    // else in the header narrows at the same moment, which is the point of the
    // switch.
    for (final (from, to) in [(320.0, 832.0), (840.0, 3440.0)]) {
      var previous = 0.0;
      for (var screen = from; screen <= to; screen += 8) {
        final cover = mangaDetailCoverWidth(columnWidth(screen));
        expect(
          cover,
          greaterThanOrEqualTo(previous),
          reason: 'the cover shrank at a ${screen}px window',
        );
        expect(cover, greaterThanOrEqualTo(110.0));
        expect(cover, lessThanOrEqualTo(200.0));
        previous = cover;
      }
    }
  });

  test('the cover stays legible either side of the two-pane switch', () {
    // 832 is the widest single-column screen and 840 the narrowest two-pane
    // one, so between them the cover is at its smallest in the wide layout.
    expect(mangaDetailCoverWidth(columnWidth(840)), greaterThan(110.0));
  });
}
