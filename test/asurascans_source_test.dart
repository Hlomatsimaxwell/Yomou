import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/sources/asurascans_source.dart';

/// Asura Scans talks to `api.asurascans.com`; these pin the source identity,
/// the URL its in-app connectivity check uses, and the split between the API
/// host and the website the user is handed. The API root answers 404, so a
/// testUrl pointing anywhere but a real endpoint makes the source look broken
/// in the tester for no reason, and an "Open in browser"/sign-in URL pointing
/// at the API host would open that same 404 page.
void main() {
  test('the source identity is stable', () {
    final source = AsuraScansSource();
    expect(source.id, 'asurascans');
    expect(source.name, 'Asura Scans');
    expect(source.baseUrl, 'https://api.asurascans.com');
  });

  test('the connectivity check targets a live endpoint, not the 404 root', () {
    expect(
      AsuraScansSource().testUrl,
      'https://api.asurascans.com/api/series?limit=1&offset=0',
    );
  });

  test('user-facing website links point at the site, not the API host', () {
    final source = AsuraScansSource();
    expect(source.websiteUrl, 'https://asurascans.com');
    expect(source.websiteUrl, isNot(source.baseUrl));
  });

  test('manga website links fall back to the site root, not a deep link', () {
    // The site addresses manga as /comics/<slug>-<hash> with a changing
    // suffix, so the *builder* cannot reconstruct a deep link from the API
    // slug; the API's public_url (see below) is the source of real links.
    final source = AsuraScansSource();
    expect(
      source.websiteMangaUrl('the-s-classes-that-i-raised'),
      'https://asurascans.com',
    );
    expect(source.websiteMangaUrl('x'), isNot(contains('api.asurascans')));
  });

  test('the API public_url becomes the absolute website page link', () {
    expect(
      AsuraScansSource.websitePageUrl('/comics/nano-machine-9a7a1ac5'),
      'https://asurascans.com/comics/nano-machine-9a7a1ac5',
    );
    expect(
      AsuraScansSource.websitePageUrl('http://cdn.example.com/x'),
      'http://cdn.example.com/x',
    );
    expect(AsuraScansSource.websitePageUrl(null), '');
  });
}