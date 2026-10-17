import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/core/widgets/responsive.dart';

/// Which window is a tablet, and who gets to decide it.
///
/// [usesWideLayout] is the app's single answer, and it is the reference's
/// `w600dp-land` resource qualifier restated: at least [kWideLayoutWidth] wide
/// *and* wider than it is tall. The rail, the two-pane settings layout and the
/// cover grids all read it, so a wrong answer here is a wrong answer in three
/// places at once -- and the covers used to answer it for themselves, which is
/// how the rail and the grids came to disagree.
///
/// The case worth pinning hardest is the split screen: a 1080p display divided
/// side by side hands each half a 948x1035dp pane. That clears every width-only
/// cut there is, and a rail plus two panes is exactly what a window shaped like
/// a portrait phone should not get. The reference goes to its phone layout
/// there because of the `-land` half of the qualifier; so does this.
void main() {
  /// A context at [width] x [height] logical pixels.
  ///
  /// One logical pixel per physical pixel, so the numbers in the cases below
  /// read as the dp they are named for.
  Future<BuildContext> contextAt(
    WidgetTester tester,
    double width,
    double height,
  ) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('context'))),
    );
    await tester.pump();
    return tester.element(find.byType(Text));
  }

  test('the tablet cut is the reference qualifier, not a local constant', () {
    expect(kWideLayoutWidth, 600);
  });

  testWidgets('a window is a tablet only when it is wide and landscape', (
    tester,
  ) async {
    const cases = <(double, double, bool)>[
      // The split-screen pane, and the same pane the other way round.
      (948.0, 1035.0, false),
      (1035.0, 948.0, true),
      // The qualifier's own edge, and one pixel inside it.
      (600.0, 400.0, true),
      (599.0, 400.0, false),
      // Square is not landscape -- the system calls that portrait, and so does
      // this -- and a tablet held upright is a phone here and in the reference,
      // because the reference's qualifier carries `-land` too.
      (600.0, 600.0, false),
      (800.0, 1280.0, false),
      // A landscape phone clears the qualifier. So does a landscape tablet.
      (800.0, 400.0, true),
      (1280.0, 800.0, true),
      // Long edge vertical, well past every width cut there is.
      (1200.0, 1600.0, false),
    ];

    for (final (width, height, expected) in cases) {
      final context = await contextAt(tester, width, height);
      expect(usesWideLayout(context), expected, reason: '${width}x$height');
    }
  });

  testWidgets('the covers cannot disagree with the rail', (tester) async {
    // The grid answers with a cell width instead of a bool, so this is the same
    // decision under both spellings: whatever the rail is doing, the covers are
    // sized for the same window.
    const cases = <(double, double)>[
      (948.0, 1035.0),
      (1035.0, 948.0),
      (600.0, 400.0),
      (599.0, 400.0),
      (600.0, 600.0),
      (800.0, 1280.0),
      (1280.0, 800.0),
    ];

    for (final (width, height) in cases) {
      final context = await contextAt(tester, width, height);
      expect(
        mangaGridBaseCellWidth(context),
        usesWideLayout(context)
            ? kMangaGridBaseCellWidthLandscape
            : kMangaGridBaseCellWidth,
        reason: '${width}x$height',
      );
    }
  });

  testWidgets('a resize is judged on the size the window has now', (
    tester,
  ) async {
    // A window launched as a tablet, split down to a pane that is still wide
    // but no longer landscape, and put back. Same process throughout: nothing
    // here is decided once at launch.
    expect(usesWideLayout(await contextAt(tester, 1280.0, 800.0)), isTrue);
    expect(usesWideLayout(await contextAt(tester, 640.0, 800.0)), isFalse);
    expect(usesWideLayout(await contextAt(tester, 1280.0, 800.0)), isTrue);
  });
}
