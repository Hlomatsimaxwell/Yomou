import 'dart:io';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/sources/madara_source.dart';
import 'package:yomou/data/models/madara_site_config.dart';

Future<void> main() async {
  final client=HttpClient();
  final req=await client.getUrl(Uri.parse('https://allporncomics.co/comic/?m_orderby=views'));
  req.headers.set('User-Agent','Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36');
  final res=await req.close();
  final body=await res.transform(SystemEncoding().decoder).join();
  print('HTTP ${res.statusCode} bytes=${body.length}');
  final cfg = MadaraSiteConfig(
    id: 'allporncomics.co',
    name: 'AllPornComics.co',
    baseUrl: 'https://allporncomics.co',
    language: 'Manga, Multi-language',
    popularPath: 'comic/?m_orderby=views',
    coverAttr: 'data-src',
    mangaCardSelector: '.page-item-detail, .c-tabs-item__content',
  );
  final src=MadaraSource(cfg);
  print('TYPE=${src.runtimeType}');
  // replicate _parseMangaGrid path via reflection is private; call toString forbidden.
  // But html available; but source parsing not exposed.
  client.close();
}
