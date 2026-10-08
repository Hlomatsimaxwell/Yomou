import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/features/onboarding/content_preferences_provider.dart';

/// The welcome sheet's two sections are filters, not decoration: whatever a
/// reader picks decides which sources appear in Explore and Search at all.
///
/// The risk that makes these worth pinning is hiding too much. A source row
/// that declares no language (a self-hosted Komga server, the mock source, a
/// row cached before the field existed) has to survive any selection, or
/// choosing "English" quietly deletes a library the reader hosts themselves.
void main() {
  Map<String, dynamic> row(String? language) {
    final map = <String, dynamic>{'name': 'Test'};
    if (language != null) map['language'] = language;
    return map;
  }

  const english = ContentPreferences(languages: {'English'});
  const manhwaOnly = ContentPreferences(formats: {'Manhwa'});

  group('with no preferences', () {
    test('every source row survives', () {
      const none = ContentPreferences();
      expect(acceptsSourceRow(row('Manga, Arabic'), none), isTrue);
      expect(acceptsSourceRow(row(null), none), isTrue);
    });
  });

  group('language selection', () {
    test('keeps rows publishing in a picked language', () {
      expect(acceptsSourceRow(row('Manga, English'), english), isTrue);
      expect(acceptsSourceRow(row('English'), english), isTrue);
      // Declared alongside formats; both are read out of the same tag list.
      expect(acceptsSourceRow(row('Manhwa, Manhua, English'), english), isTrue);
    });

    test('drops rows publishing only in languages that were not picked', () {
      expect(acceptsSourceRow(row('Manga, Arabic'), english), isFalse);
      expect(acceptsSourceRow(row('Manga, Spanish'), english), isFalse);
    });

    test('a language is matched on any of its spellings', () {
      const portuguese = ContentPreferences(languages: {'Portuguese'});
      expect(acceptsSourceRow(row('Manga, Portuguese'), portuguese), isTrue);
      expect(acceptsSourceRow(row('Manga, Portuguese (BR)'), portuguese), isTrue);
    });
  });

  group('rows that declare nothing the filter understands', () {
    test('survive any selection', () {
      // Komga: a server the reader hosts themselves.
      expect(acceptsSourceRow(row('Self-hosted (API)'), english), isTrue);
      expect(acceptsSourceRow(row('Mock'), english), isTrue);
      // No `language` key at all, as written before the field existed.
      expect(acceptsSourceRow(row(null), english), isTrue);
      // Not pinned to one scanlation language.
      expect(acceptsSourceRow(row('Manga, Various languages'), english), isTrue);
    });
  });

  group('format selection', () {
    test('keeps rows declaring a picked format', () {
      expect(acceptsSourceRow(row('Manhwa, Manhua, English'), manhwaOnly), isTrue);
    });

    test('drops rows declaring only other formats', () {
      expect(acceptsSourceRow(row('Manga, English'), manhwaOnly), isFalse);
    });

    test('rows declaring no format survive', () {
      expect(acceptsSourceRow(row('English'), manhwaOnly), isTrue);
      expect(acceptsSourceRow(row(null), manhwaOnly), isTrue);
    });

    test('formats and languages filter together', () {
      const both = ContentPreferences(languages: {'English'}, formats: {'Manhwa'});
      expect(acceptsSourceRow(row('Manhwa, English'), both), isTrue);
      // Right language, wrong format.
      expect(acceptsSourceRow(row('Manga, English'), both), isFalse);
      // Right format, wrong language.
      expect(acceptsSourceRow(row('Manhwa, Arabic'), both), isFalse);
    });
  });
}
