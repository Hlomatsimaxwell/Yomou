import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/sources/asia_lotuss_source.dart';

void main() {
  group('AsiaLotussSource - identity', () {
    test('has correct ID', () {
      final source = AsiaLotussSource();
      expect(source.id, 'asialotuss');
      expect(source.name, 'Asia Lotuss');
      expect(source.baseUrl, 'https://asialotuss.com');
      expect(source.languageCode, 'es');
    });
  });
}
