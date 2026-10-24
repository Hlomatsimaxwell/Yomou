import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/widgets/source_icon.dart';

int _kotlinStringHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0xFFFFFFFF;
    if (h >= 0x80000000) h -= 0x100000000;
    if (h < -0x80000000) h += 0x100000000;
  }
  return h;
}

void main() {
  testWidgets('a source without a logo wears the Kotatsu letter tile',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SourceIcon(name: 'MangaKings', size: 56),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The letter, big and bold, in the name's own hue -- the same hue recipe
    // KotatsuColors.random follows, so the identical name lands on the
    // identical hue in both apps.
    final letterText = tester.widget<Text>(find.text('M'));
    final hue = (_kotlinStringHash('MangaKings').abs() % 360).toDouble();
    final expectedRaw = HSLColor.fromAHSL(1, hue, 0.5, 0.5).toColor();
    final theme = Theme.of(tester.element(find.text('M')));
    final expectedLetter = Color.lerp(expectedRaw, theme.colorScheme.surface, 0.15)!;
    expect(letterText.style!.fontWeight, FontWeight.bold);
    expect(letterText.style!.color, expectedLetter);
    final fitted = _fittedSize('M', 56);
    expect(letterText.style!.fontSize, closeTo(fitted, 0.5));
  });

  testWidgets('the tile takes the theme surface with an outline stroke',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SourceIcon(name: 'SekteKomik', size: 56),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final theme = Theme.of(tester.element(find.byType(SourceIcon)));
    // The tile owns the surface fill; the plate's own box is a different
    // one, and the fallback adds no rim of its own.
    final box = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(SourceIcon),
            matching: find.byType(DecoratedBox),
          ),
        )
        .where(
          (w) => (w.decoration as BoxDecoration).color == theme.colorScheme.surface,
        )
        .first;
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, theme.colorScheme.surface);
    expect(decoration.border, isNull);
  });

  testWidgets('the letter colour is deterministic per name', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Column(
              children: [
                SourceIcon(name: 'MangaFire', size: 56),
                SourceIcon(name: 'MangaBall Arabic', size: 56),
                SourceIcon(name: 'MangaFire', size: 56),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final texts = List.of(
      tester.widgetList<Text>(find.byType(Text)).where((t) => t.style?.color != null),
    );
    final first = texts.first.style!.color;
    final second = texts.last.style!.color;
    expect(second, first, reason: 'same name must repeat its hue');
  });
}

double _fittedSize(String letter, double size) {
  const probe = 48.0;
  final painter = TextPainter(
    text: TextSpan(
      text: letter.toUpperCase(),
      style: const TextStyle(fontSize: probe, fontWeight: FontWeight.bold),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return probe * size / painter.width * 0.5;
}
