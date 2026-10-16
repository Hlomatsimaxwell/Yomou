import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// A chapter row used to read "Chapter 12" on every line, with the number the
/// only thing that changed between them. At list weight, spelled out on every
/// row, that is the heaviest text in the list -- it turns scanning for a chapter
/// into reading the list.
///
/// This pins the replacement: the row abbreviates to "Ch.12", and a chapter the
/// source never numbered keeps its own title rather than being flattened into a
/// bare "Ch.".
void main() {
  late AppLocalizations en;
  late AppLocalizations es;

  setUpAll(() async {
    // Through the real delegate, so these assert the shipped strings rather
    // than a stand-in.
    en = await AppLocalizations.delegate.load(const Locale('en'));
    es = await AppLocalizations.delegate.load(const Locale('es'));
  });

  test('a numbered chapter abbreviates to Ch.', () {
    // The literal, not just the getter: routing the assertion through
    // chapterNumShort would still pass if that string went back to spelling the
    // word out, which is the regression worth catching.
    expect(
      mangaDetailChapterLabel(
        l: en,
        chapterNumber: '12',
        title: 'Chapter 12',
      ),
      'Ch.12',
    );
  });

  test('the abbreviation is shorter than the word it replaced', () {
    expect(
      en.chapterNumShort('12').length,
      lessThan(en.chapterNum('12').length),
    );
  });

  test('a decimal chapter keeps the number as published', () {
    expect(
      mangaDetailChapterLabel(
        l: en,
        chapterNumber: '12.5',
        title: 'Chapter 12.5',
      ),
      'Ch.12.5',
    );
  });

  test('an unnumbered chapter keeps its own title', () {
    // Sources that publish extras and specials leave the number as a sentinel,
    // and "Ch." on its own would identify nothing.
    expect(
      mangaDetailChapterLabel(l: en, chapterNumber: 'Chapter', title: 'Extra'),
      'Extra',
    );
    expect(
      mangaDetailChapterLabel(l: en, chapterNumber: '', title: 'Omake'),
      'Omake',
    );
  });

  test('the abbreviation is translated rather than hardcoded', () {
    expect(
      mangaDetailChapterLabel(l: es, chapterNumber: '3', title: 'Capítulo 3'),
      'Cap.3',
    );
  });

  test('the pane mode control has names, so it is not icon-only', () {
    // The docked pane shows these three as a segmented control. The middle one
    // lists the pages of the chapter you are on, not a grid of chapters, which
    // is why it is labelled "Pages" rather than "Grid view".
    expect(en.detailTabChapters, 'Chapters');
    expect(en.detailTabPages, 'Pages');
    expect(en.bookmarks, 'Bookmarks');
  });
}
