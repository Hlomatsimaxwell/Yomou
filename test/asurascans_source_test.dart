import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/sources/asurascans_source.dart';

/// Asura Scans talks to `api.asurascans.com`; these pin the source identity
/// and the URL its in-app connectivity check uses. The API root answers 404,
/// so a testUrl pointing anywhere but a real endpoint makes the source look
/// broken in the tester for no reason.
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
}