#!/usr/bin/env python3
"""Generate lib/data/sources/catalog/madara_catalog.g.dart.

Input (all local, gitignored under .data/):
  sources_catalog.json  - deduped sites (name/icon/lang/nsfw)
  madara_validation.json - go/no-go sweep result per host

Only hosts whose listing, detail, chapter list and reader page all responded
are emitted, so every bundled source has been seen working at least once.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / ".data"
OUT = ROOT / "lib/data/sources/catalog/madara_catalog.g.dart"

# Hosts that already ship as a hand-written source in lib/data/sources/, or
# that the registry already lists under another name. Bundling a catalog copy
# would give the reader two rows pointing at the same site.
SKIP_HOSTS = {
    "apollcomics.es",
    "begatranslation.com",
    "infrafandub.com",
    "manhuaplus.com",
    "asialotuss.com",
    "arenascan.com",
    "datgarscanlation.blogspot.com",
}

LANG_NAMES = {
    "en": "English", "ja": "Japanese", "ko": "Korean", "zh": "Chinese",
    "zh-Hans": "Chinese", "zh-Hant": "Chinese", "es": "Spanish",
    "pt": "Portuguese", "pt-BR": "Portuguese (BR)", "fr": "French",
    "it": "Italian", "de": "German", "ru": "Russian", "ar": "Arabic",
    "id": "Indonesian", "th": "Thai", "vi": "Vietnamese", "tr": "Turkish",
    "pl": "Polish", "uk": "Ukrainian", "cs": "Czech", "hu": "Hungarian",
    "ro": "Romanian", "nl": "Dutch", "sv": "Swedish", "no": "Norwegian",
    "da": "Danish", "el": "Greek", "he": "Hebrew", "hi": "Hindi",
    "bn": "Bengali", "bg": "Bulgarian", "ca": "Catalan", "ms": "Malay",
    "ta": "Tamil", "fa": "Persian", "sr": "Serbian", "hr": "Croatian",
    "sk": "Slovak", "sl": "Slovenian", "sq": "Albanian", "af": "Afrikaans",
    "is": "Icelandic", "fil": "Filipino", "tl": "Filipino",
    "ne": "Nepali", "all": "Multi-language",
}


def main():
    validation = json.load(open(DATA / "madara_validation.json"))
    catalog = {c["host"]: c for c in json.load(open(DATA / "sources_catalog.json"))}

    entries, seen_names = [], set()
    for row in validation:
        if row["verdict"] != "ok":
            continue
        host = row["host"]
        if host in SKIP_HOSTS:
            continue
        cat = catalog.get(host)
        if not cat:
            continue
        name = cat["name"].strip() or host
        if name in seen_names:
            name = f"{name} ({host})"
        seen_names.add(name)
        code = cat["langs"][0] if cat["langs"] else "all"
        language = LANG_NAMES.get(code, "Multi-language")
        entries.append({
            "id": re.sub(r"-", "_", host),
            "name": name,
            "baseUrl": f"https://{host}",
            "iconUrl": cat.get("icon") or "",
            "language": f"Manga, {language}",
            "nsfw": bool(cat.get("nsfw")),
        })

    entries.sort(key=lambda e: e["name"].lower())

    payload = json.dumps(entries, ensure_ascii=False, separators=(",", ":"))
    dart = f'''// GENERATED FILE - do not edit by hand.
//
// Regenerate with tool/catalog/gen_madara_catalog.py after a validation sweep.
// Each entry is a Madara site whose listing, detail page, chapter list and
// reader all answered during that sweep; they are bundled as generic
// [MadaraSource]s instead of one hand-written class per site.
//
// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:yomou/data/models/madara_site_config.dart';

/// Compact catalog payload: id, name, baseUrl, iconUrl, language, nsfw.
const String kCatalogMadaraJson = r\'\'\'{payload}\'\'\';

List<MadaraSiteConfig>? _configs;

/// Every bundled Madara site, parsed once.
List<MadaraSiteConfig> get catalogMadaraConfigs =>
    _configs ??= [
      for (final raw in jsonDecode(kCatalogMadaraJson) as List)
        _configFrom((raw as Map).cast<String, dynamic>()),
    ];

/// The catalog's sites keyed by display name, which is what the registry rows
/// and `getSourceByName` use.
final Map<String, MadaraSiteConfig> catalogMadaraByName = {{
  for (final config in catalogMadaraConfigs) config.name: config,
}};

/// Source-list rows for the catalog. Disabled by default: 90+ extra sources
/// would otherwise join every global search fan-out and updates refresh before
/// the reader has asked for any of them.
List<Map<String, dynamic>> get catalogSourceRows => [
  for (final raw in jsonDecode(kCatalogMadaraJson) as List)
    {{
      'name': (raw as Map)['name'] as String,
      'language': raw['language'] as String,
      'iconUrl': raw['iconUrl'] as String? ?? '',
      'isPinned': false,
      'isEnabled': false,
      if (raw['nsfw'] == true) 'nsfw': true,
    }},
];

MadaraSiteConfig _configFrom(Map<String, dynamic> raw) => MadaraSiteConfig(
  id: raw['id'] as String,
  name: raw['name'] as String,
  baseUrl: raw['baseUrl'] as String,
  language: raw['language'] as String,
  iconUrl: raw['iconUrl'] as String? ?? '',
  // Madara lazy-loads both covers and reader pages, so the real URL lives in
  // data-src; the engine falls back to src for sites that do not.
  coverAttr: 'data-src',
  mangaCardSelector: '.page-item-detail, .c-tabs-item__content',
  // Madara sites disagree on whether the chapter list is nested in ul.main,
  // and some mark reader images with a class instead of the id.
  chapterListSelector: 'ul.main li.wp-manga-chapter, li.wp-manga-chapter',
  readerImageSelector: '.wp-manga-chapter-img, #reading-content img',
);
'''
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(dart)
    print(f"wrote {OUT} ({len(entries)} sites, {len(dart)} bytes)")


if __name__ == "__main__":
    main()
