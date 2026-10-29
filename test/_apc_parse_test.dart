import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/data/sources/madara_source.dart';
import 'package:yomou/data/models/madara_site_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String,Object>{});
  test('apc parse popular', () async {
    final cfg = MadaraSiteConfig(
      id: 'allporncomics.co',
      name: 'AllPornComics.co',
      baseUrl: 'https://allporncomics.co',
      language: 'Manga, Multi-language',
      iconUrl: 'https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/all/allporncomicsco/res/mipmap-xhdpi/ic_launcher.png',
      popularPath: 'comic/?m_orderby=views',
      coverAttr: 'data-src',
      mangaCardSelector: '.page-item-detail, .c-tabs-item__content',
    );
    final src = MadaraSource(cfg);
    final html = await src.grabText('https://allporncomics.co/comic/?m_orderby=views', useBaseUrl: false);
    print('APC HTMLLEN=${html.length}');
    final list = await src.getPopularManga();
    print('APC COUNT=${list.length}');
    for (final m in list.take(8)) {
      print('  - ${m.id}: ${m.title}');
    }
    expect(list.length, greaterThan(0));
  });
}
