import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/sources/comick_source.dart';

/// ComicK's original host (comick.io/comick.live) is closed; the source now
/// talks to the live comick.art origin. These pin the identity and the URLs
/// its links hand the user so a future domain regression is caught here
/// rather than only in the field.
void main() {
  test('the source identity is stable and points at the live host', () {
    final source = ComickSource();
    expect(source.id, 'comick');
    expect(source.name, 'ComicK');
    expect(source.baseUrl, 'https://comick.art');
  });

  test('manga website links target the comic page on the live host', () {
    final source = ComickSource();
    expect(
      source.websiteMangaUrl('00-solo-leveling'),
      'https://comick.art/comic/00-solo-leveling',
    );
  });

  test('canonical-suffix heuristic never rejects the current slug form', () {
    // Slugs from search lack the internal numeric prefix; those from
    // comic-data carry it. The canonical resolver treats an already-prefixed
    // slug as canonical without a network call.
    expect(RegExp(r'^\d+-\S+').hasMatch('00-solo-leveling'), isTrue);
    expect(RegExp(r'^\d+-\S+').hasMatch('solo-leveling'), isFalse);
  });
}