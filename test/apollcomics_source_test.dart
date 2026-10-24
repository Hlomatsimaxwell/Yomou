import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/sources/apollcomics_source.dart';

void main() {
  group('ApollComicsSource - identity', () {
    test('has correct ID', () {
      final source = ApollComicsSource();
      expect(source.id, 'apollcomics');
      expect(source.name, 'Apoll Comics');
      expect(source.baseUrl, 'https://apollcomics.es');
      expect(source.languageCode, 'es');
    });
  });
}
