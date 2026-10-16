import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/widgets/kotatsu_icon.dart';

/// The settings glyphs ported from Kotatsu-Redo ship as asset files rather than
/// an icon font, so nothing at compile time knows they exist. A mistyped name,
/// or an asset directory dropped from pubspec, would show up as a blank slot on
/// the real settings screen; these catch it in a test instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every ported glyph is bundled and carries real geometry', () async {
    expect(kKotatsuIconNames, isNotEmpty);
    expect(
      kKotatsuIconNames.toSet().length,
      kKotatsuIconNames.length,
      reason: 'duplicate name in kKotatsuIconNames',
    );

    for (final name in kKotatsuIconNames) {
      final data = await rootBundle.load('$kKotatsuIconDir/$name.svg');
      final svg = utf8.decode(data.buffer.asUint8List());
      expect(svg, contains('<svg'), reason: '$name is not an svg');
      expect(svg, contains('<path'), reason: '$name has no path data');
      // The files are converted Android drawables; any leftover `android:`
      // attribute means the conversion leaked rather than translated.
      expect(
        svg,
        isNot(contains('android:')),
        reason: '$name still carries Android attributes',
      );
    }
  });

  test('every glyph the app names is in the list', () {
    // The list is what the bundling test above walks and what a caller warming
    // the cache would iterate, so a name used in code but left out of it is a
    // glyph that ships untested and unprecached -- `ic_badges` was exactly that
    // until this caught it.
    final used = <String>{};
    final pattern = RegExp(r"KotatsuIcon\(\s*'([a-z_0-9]+)'");
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      used.addAll(
        pattern.allMatches(entity.readAsStringSync()).map((m) => m.group(1)!),
      );
    }

    expect(used, isNotEmpty, reason: 'found no KotatsuIcon( usage to check');
    expect(
      used.difference(kKotatsuIconNames.toSet()),
      isEmpty,
      reason: 'used in lib/ but missing from kKotatsuIconNames',
    );
  });

  testWidgets('takes its size and colour from the surrounding IconTheme', (
    tester,
  ) async {
    // This is what makes it drop-in where an Icon would go: inside a ListTile
    // the tile supplies an IconTheme, so the row colours the glyph without the
    // caller naming a colour.
    await tester.pumpWidget(
      const MaterialApp(
        home: IconTheme(
          data: IconThemeData(color: Color(0xFF123456), size: 24),
          child: KotatsuIcon('ic_dark_mode'),
        ),
      ),
    );

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(picture.width, 24);
    expect(picture.height, 24);
    expect(
      picture.colorFilter,
      const ColorFilter.mode(Color(0xFF123456), BlendMode.srcIn),
    );
    expect(
      (picture.bytesLoader as SvgAssetLoader).assetName,
      '$kKotatsuIconDir/ic_dark_mode.svg',
    );
  });

  testWidgets('an explicit colour and size win over the IconTheme', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IconTheme(
          data: IconThemeData(color: Color(0xFF123456), size: 24),
          child: KotatsuIcon('ic_lock', size: 20, color: Color(0xFFABCDEF)),
        ),
      ),
    );

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(picture.width, 20);
    expect(picture.height, 20);
    expect(
      picture.colorFilter,
      const ColorFilter.mode(Color(0xFFABCDEF), BlendMode.srcIn),
    );
  });
}
