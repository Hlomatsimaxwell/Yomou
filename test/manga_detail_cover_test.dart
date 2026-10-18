import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';

/// The detail header's cover was a fixed 125x175 at every width, then reduced
/// to a smaller footprint so the title and metadata beside it keep their room.
/// The phone lands on a 110px floor, a wide pane grows to a larger cover, and
/// a 200px ceiling holds the wide pane so a large monitor does not turn the
/// header into a poster. The phone layout takes no ceiling at all, so an
/// in-between window (a split screen, a foldable half) keeps the cover
/// growing the way the reference's share-of-window cover does.
///
/// These pin the ends of that change: the floor, the growth, the ceilings
/// (per layout), and that the cover never reshapes as it grows.
void main() {
  /// The width the header section is actually given, which is what the cover is
  /// measured against.
  ///
  /// On a wide layout it is one pane of the split first -- the screen is 5/11 of
  /// the width the window gave the app, because the other 6/11 belongs to the
  /// chapter list beside it -- and only then does the section's own
  /// `EdgeInsets.symmetric(horizontal: 16)` come off each side.
  ///
  /// The switch is [usesWideLayout]'s, so it is [kWideLayoutWidth] and not a
  /// second number of this test's. These sweeps are of a window wider than it
  /// is tall, which is the window in which the split happens at all.
  double columnWidth(double screenWidth) =>
      (screenWidth >= kWideLayoutWidth ? screenWidth * 5 / 11 : screenWidth) - 32;

  /// The gap between the cover and the title block, which the cover may not eat.
  const double gap = 16;

  test('a phone gets the smaller cover the redesign asks for', () {
    // 360 is the narrowest phone this app is used on, and 328 is what its
    // header section is given. The floor is 110 wide.
    expect(columnWidth(360), 328.0);
    expect(mangaDetailCoverWidth(328.0, capped: false), 110.0);
  });

  test('a phone in any other width is not made smaller or larger by mistake', () {
    // A 320px phone has a narrower column than the 328 the share was solved
    // against, so it has to be held at the floor rather than shrink.
    expect(mangaDetailCoverWidth(288.0, capped: false), 110.0);
    // A large-font phone in landscape, and a small tablet in portrait: both are
    // wide layouts, so both get a real cover rather than the phone's.
    expect(mangaDetailCoverWidth(740.0), greaterThan(110.0));
  });

  test('an in-between window grows the cover past the old ceiling', () {
    // A side-by-side split on a large display is taller than it is wide, so it
    // stays in the phone layout even at widths no phone has -- and there the
    // cover takes no ceiling, the way the reference's cover (a share of the
    // window, no cap, in every layout variant) keeps pace with the window.
    // 800 is such a window; the phone layout only takes the 32px padding off.
    final cover = mangaDetailCoverWidth(800 - 32, capped: false);
    expect(cover, greaterThan(200.0));
    // The reference shows 30% of the same window, so our 32% share is at least
    // its size rather than quietly smaller.
    expect(cover, greaterThanOrEqualTo(0.30 * 800));
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
    // Swept per layout, not across the switch: the switch is where the section
    // stops being the whole screen and becomes one pane of a 5:6 split, so the
    // column it was given drops from 560 at 592px to 241 at 600px and the cover
    // with it. That is the layout changing, not the cover retreating -- and
    // everything else in the header narrows at the same moment, which is the
    // point of the switch.
    for (final (from, to, capped) in [
      (320.0, 592.0, false),
      (600.0, 3440.0, true),
    ]) {
      var previous = 0.0;
      for (var screen = from; screen <= to; screen += 8) {
        final cover = mangaDetailCoverWidth(columnWidth(screen), capped: capped);
        expect(
          cover,
          greaterThanOrEqualTo(previous),
          reason: 'the cover shrank at a ${screen}px window',
        );
        expect(cover, greaterThanOrEqualTo(110.0));
        // The ceiling binds the wide pane; the phone layout answers to no
        // ceiling, though none of its windows are wide enough to reach one.
        if (capped) expect(cover, lessThanOrEqualTo(200.0));
        previous = cover;
      }
    }
  });

  test('the cover holds the phone floor at the two-pane switch', () {
    // 592px is the widest single-column window and 600 the narrowest two-pane
    // one, so the pane the cover lands in is at its narrowest right after the
    // switch. That is where the cover would go below the phone's 110 if
    // anything could push it there; the floor is what holds it up.
    expect(columnWidth(600), lessThan(columnWidth(592)));
    expect(mangaDetailCoverWidth(columnWidth(600)), 110.0);
    // It stays on the floor while the pane grows around it, and only starts to
    // grow once there is room to spare for it beside the title.
    expect(mangaDetailCoverWidth(columnWidth(824)), 110.0);
    expect(mangaDetailCoverWidth(columnWidth(840)), greaterThan(110.0));
  });
}
