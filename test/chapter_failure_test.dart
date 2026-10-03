import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// When the chapter list will not load, the screen used to report "This source
/// is not supported from here" whenever the source could not be resolved, and
/// throw away the failure message that was actually available. Any other cause
/// -- a timeout, a parse change, a captcha -- was therefore reported as a
/// missing source, naming a cause that had never been established.
void main() {
  late AppLocalizations l;

  setUpAll(() async {
    // The lookup is driven through the real generated delegate so this asserts
    // the shipped strings, not a stand-in.
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('a real failure reports itself, not a verdict on the source', () {
    expect(
      mangaDetailChapterFailure(
        l: l,
        sourceMissing: true,
        error: 'Connection timed out',
      ),
      'Connection timed out',
    );
  });

  test('a resolved source that failed still reports its failure', () {
    expect(
      mangaDetailChapterFailure(
        l: l,
        sourceMissing: false,
        error: 'Connection timed out',
      ),
      'Connection timed out',
    );
  });

  test('only a genuinely absent source is called unsupported', () {
    expect(
      mangaDetailChapterFailure(l: l, sourceMissing: true),
      l.sourceNotSupported,
    );
  });

  test('an empty failure message does not blank the line', () {
    // An empty string is a failure that produced no text; saying "not
    // supported" there would be the same unsupported claim as before.
    expect(
      mangaDetailChapterFailure(l: l, sourceMissing: true, error: ''),
      l.sourceNotSupported,
    );
    expect(
      mangaDetailChapterFailure(l: l, sourceMissing: false, error: ''),
      l.noChaptersAvailable,
    );
  });

  test('neither cause: the heading is repeated, not invented', () {
    expect(
      mangaDetailChapterFailure(l: l, sourceMissing: false),
      l.noChaptersAvailable,
    );
  });
}
