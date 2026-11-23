// GENERATED FILE - do not edit by hand.
//
// Built from .data/engines.json (theme: zeistmanga) and
// .data/sources_catalog.json (icons + nsfw flags). Every ZeistManga engine
// shares the same Blogger-feed theme, so all of these sites are served by the
// generic [ZeistMangaSource] instead of one hand-written class per site.
//
// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:yomou/data/models/zeistmanga_site_config.dart';

/// Compact catalog payload: id, name, baseUrl, langCode, language, iconUrl,
/// nsfw, mangaCategory and optional pageSelector.
const String kCatalogZeistMangaJson = r'''[{"id":"6495978594979776478","name":"Aarlas","baseUrl":"https://www.arlas.online","langCode":"id","language":"Manga, Indonesian","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/id/aarlas/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"6897166867127039489","name":"Apenas Uma Fã","baseUrl":"https://apenasuma-fa.blogspot.com","langCode":"pt-BR","language":"Manga, Portuguese (BR)","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/core/src/main/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"7487319247633385575","name":"Comic Verse","baseUrl":"https://arcomixverse.blogspot.com","langCode":"ar","language":"Manga, Arabic","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/ar/comicverse/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"2769673412724723872","name":"Dark Room Fansub","baseUrl":"https://lector-darkroomfansub.blogspot.com","langCode":"es","language":"Manga, Spanish","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/es/darkroomfansub/res/mipmap-xhdpi/ic_launcher.png","nsfw":true},{"id":"5553519415877811746","name":"GALAX Scans","baseUrl":"https://galaxscanlator.blogspot.com","langCode":"pt-BR","language":"Manga, Portuguese (BR)","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/pt/galaxscanlator/res/mipmap-xhdpi/ic_launcher.png","nsfw":false,"mangaCategory":"Recentes"},{"id":"2374282752350973310","name":"Hanmokku Scan","baseUrl":"https://hanmokkuscan.blogspot.com","langCode":"pt-BR","language":"Manga, Portuguese (BR)","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/pt/hanmokkuscan/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"8948534014820087218","name":"KazeScans","baseUrl":"https://www.kazescans.com","langCode":"tr","language":"Manga, Turkish","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/tr/kazescans/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"1601772753251290758","name":"LepoyTL","baseUrl":"https://www.lepoytl.my.id","langCode":"id","language":"Manga, Indonesian","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/id/lepoytl/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"11864058740306611","name":"Ler 999","baseUrl":"https://ler999.blogspot.com","langCode":"pt-BR","language":"Manga, Portuguese (BR)","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/pt/ler999/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"323105186892383931","name":"Loner Translations","baseUrl":"https://loner-tl.blogspot.com","langCode":"ar","language":"Manga, Arabic","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/ar/lonertranslations/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"7109397520501699498","name":"Manga Ai Land","baseUrl":"https://manga-ai-land.blogspot.com","langCode":"ar","language":"Manga, Arabic","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/ar/mangaailand/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"743599002989616408","name":"Manhatok","baseUrl":"https://manhatok.blogspot.com","langCode":"ar","language":"Manga, Arabic","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/ar/manhatok/res/mipmap-xhdpi/ic_launcher.png","nsfw":false,"pageSelector":"#seoneurons-target img"},{"id":"1959637408417261960","name":"Mikrokosmos Fansub","baseUrl":"https://mikrokosmosfb.blogspot.com","langCode":"tr","language":"Manga, Turkish","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/tr/mikrokosmosfansub/res/mipmap-xhdpi/ic_launcher.png","nsfw":true},{"id":"4966914277555229831","name":"Murim","baseUrl":"https://www.murim.site","langCode":"ar","language":"Manga, Arabic","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/ar/murim/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"5524031489110351257","name":"MurimScan","baseUrl":"https://www.murimscans.site","langCode":"en","language":"Manga, English","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/en/murimscan/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"4607768416266139943","name":"NgamenKomik","baseUrl":"https://ngamenkomik05.blogspot.com","langCode":"id","language":"Manga, Indonesian","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/id/ngamenkomik/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"8361715798247396418","name":"OkyyKomik","baseUrl":"https://www.okyykomik.my.id","langCode":"id","language":"Manga, Indonesian","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/id/okyykomik/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"5634203247016722993","name":"Orca Manga","baseUrl":"https://infinity896.blogspot.com","langCode":"ar","language":"Manga, Arabic","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/ar/orcamanga/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"8456404960509331854","name":"Pink Rosa","baseUrl":"https://scanpinkrosa.blogspot.com","langCode":"pt-BR","language":"Manga, Portuguese (BR)","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/pt/pinkrosa/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"1645729642561182833","name":"ReYume","baseUrl":"https://www.re-yume.my.id","langCode":"id","language":"Manga, Indonesian","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/id/inazumanga/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"3852979672050614736","name":"Shadow Çeviri","baseUrl":"https://shadowceviri.blogspot.com","langCode":"tr","language":"Manga, Turkish","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/tr/shadowceviri/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"7106013231844823613","name":"ShiyuraSub","baseUrl":"https://shiyurasub.blogspot.com","langCode":"id","language":"Manga, Indonesian","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/id/shiyurasub/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"677370205708439700","name":"Temaki mangás","baseUrl":"https://temakimangas.blogspot.com","langCode":"pt-BR","language":"Manga, Portuguese (BR)","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/pt/temakimangas/res/mipmap-xhdpi/ic_launcher.png","nsfw":true,"pageSelector":"#reader div.separator img"},{"id":"8493327683322555504","name":"Tooncubus","baseUrl":"https://www.tooncubus.top","langCode":"id","language":"Manga, Indonesian","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/id/tooncubus/res/mipmap-xhdpi/ic_launcher.png","nsfw":true},{"id":"3650511144741653873","name":"Traduções do Lipe","baseUrl":"https://traducoesdolipe.blogspot.com","langCode":"pt-BR","language":"Manga, Portuguese (BR)","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/pt/traducoesdolipe/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"440952493414630310","name":"Ulas Comic","baseUrl":"https://www.ulascomic01.xyz","langCode":"id","language":"Manga, Indonesian","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/id/ulascomic/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"6170348197605244575","name":"XSano Manga","baseUrl":"https://www.xsano-manga.com","langCode":"ar","language":"Manga, Arabic","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/ar/xsanomanga/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"4337506350787725909","name":"Yokai","baseUrl":"https://yokai-team.blogspot.com","langCode":"ar","language":"Manga, Arabic","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/ar/yokai/res/mipmap-xhdpi/ic_launcher.png","nsfw":false},{"id":"7833471811016150678","name":"Yuri Moon Sub","baseUrl":"https://yurimoonsub.blogspot.com","langCode":"ar","language":"Manga, Arabic","iconUrl":"https://cdn.jsdelivr.net/gh/keiyoushi/extensions-source@main/src/ar/yurimoonsub/res/mipmap-xhdpi/ic_launcher.png","nsfw":true}]''';

List<ZeistMangaSiteConfig>? _configs;

/// Every bundled ZeistManga site, parsed once.
List<ZeistMangaSiteConfig> get catalogZeistMangaConfigs =>
    _configs ??= [
      for (final raw in jsonDecode(kCatalogZeistMangaJson) as List)
        ZeistMangaSiteConfig.fromJson(
          (raw as Map).cast<String, dynamic>(),
        ),
    ];

/// The catalog's sites keyed by display name, which is what the registry rows
/// and `getSourceByName` use.
final Map<String, ZeistMangaSiteConfig> catalogZeistMangaByName = {
  for (final config in catalogZeistMangaConfigs) config.name: config,
};

/// The same sites keyed by id, which is what a stored manga row carries as its
/// `sourceId`.
final Map<String, ZeistMangaSiteConfig> catalogZeistMangaById = {
  for (final config in catalogZeistMangaConfigs) config.id: config,
};

/// Source-list rows for the catalog.
List<Map<String, dynamic>> get catalogZeistMangaSourceRows => [
  for (final config in catalogZeistMangaConfigs)
    {
      'name': config.name,
      'language': config.language,
      'iconUrl': config.iconUrl,
      // The site itself, not the CDN its icon happens to live on.
      'siteUrl': config.baseUrl,
      'isPinned': false,
      'isEnabled': true,
      if (config.baseUrl.isNotEmpty && config.isNsfw) 'nsfw': true,
    },
];
