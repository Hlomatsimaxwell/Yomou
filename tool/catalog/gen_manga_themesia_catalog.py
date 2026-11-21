#!/usr/bin/env python3
"""Generate lib/data/sources/catalog/manga_themesia_catalog.g.dart.

Input (all local, gitignored under .data/):
  engines.json         - extension engines; every one with theme=mangathemesia
                         contributes a site
  sources_catalog.json - deduped site names, icons, languages and nsfw flags

One generic [MangaThemesiaSource] serves every bundled site, so adding a site
means adding its rows to the two JSON files and re-running this script. The
output is committed; the .data/ files are not.

Usage:
  python3 tool/catalog/gen_manga_themesia_catalog.py
  python3 tool/catalog/gen_manga_themesia_catalog.py --check   # CI / pre-commit
"""
import argparse
import json
import sys
from pathlib import Path

from catalog_common import CATALOG_DIR, DATA, bare_host, language_label

OUT = CATALOG_DIR / "manga_themesia_catalog.g.dart"


def build_entries():
    engines = json.load(open(DATA / "engines.json", encoding="utf-8"))
    catalog = {
        row["host"]: row
        for row in json.load(open(DATA / "sources_catalog.json", encoding="utf-8"))
    }

    entries = []
    for engine in engines:
        if engine.get("theme") != "mangathemesia":
            continue
        sources = engine.get("sources") or []
        if not sources:
            continue
        source = sources[0]  # one row per engine; see the multi-language note below
        url = (source.get("homeUrl") or "").rstrip("/")
        if not url:
            continue
        host = bare_host(url)
        site = catalog.get(host)
        if not site:
            print(f"warning: no sources_catalog.json row for {host}", file=sys.stderr)
            continue
        entries.append({
            "id": source["id"],
            "name": site["name"].strip() or host,
            "baseUrl": url,
            "langCode": source.get("language"),
            "language": language_label(site.get("langs")),
            "iconUrl": site.get("icon") or "",
            "nsfw": bool(site.get("nsfw")),
            # Every bundled MangaThemesia engine uses the stock /manga archive
            # path; an engine that renames it needs an explicit override in the
            # .g.dart entry and a matching field in MangaThemesiaSiteConfig.
            "mangaUrlDirectory": "/manga",
        })

    entries.sort(key=lambda entry: entry["name"].lower())
    return entries


def render(entries):
    payload = json.dumps(entries, ensure_ascii=False, separators=(",", ":"))
    return f'''// GENERATED FILE - do not edit by hand.
//
// Built from .data/engines.json (theme: mangathemesia) and
// .data/sources_catalog.json (icons + nsfw flags). Every MangaThemesia engine
// shares one theme library, so all of these sites are served by the generic
// [MangaThemesiaSource] instead of one hand-written class per site.
//
// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:yomou/data/models/manga_themesia_site_config.dart';

/// Compact catalog payload: id, name, baseUrl, langCode, language, iconUrl,
/// nsfw, mangaUrlDirectory.
const String kCatalogMangaThemesiaJson = r\'\'\'{payload}\'\'\';

List<MangaThemesiaSiteConfig>? _configs;

/// Every bundled MangaThemesia site, parsed once.
List<MangaThemesiaSiteConfig> get catalogMangaThemesiaConfigs =>
    _configs ??= [
      for (final raw in jsonDecode(kCatalogMangaThemesiaJson) as List)
        MangaThemesiaSiteConfig.fromJson(
          (raw as Map).cast<String, dynamic>(),
        ),
    ];

/// The catalog's sites keyed by display name, which is what the registry rows
/// and `getSourceByName` use.
final Map<String, MangaThemesiaSiteConfig> catalogMangaThemesiaByName = {{
  for (final config in catalogMangaThemesiaConfigs) config.name: config,
}};

/// The same sites keyed by id, which is what a stored manga row carries as its
/// `sourceId`.
final Map<String, MangaThemesiaSiteConfig> catalogMangaThemesiaById = {{
  for (final config in catalogMangaThemesiaConfigs) config.id: config,
}};

/// Source-list rows for the catalog.
List<Map<String, dynamic>> get catalogMangaThemesiaSourceRows => [
  for (final config in catalogMangaThemesiaConfigs)
    {{
      'name': config.name,
      'language': config.language,
      'iconUrl': config.iconUrl,
      // The site itself, not the CDN its icon happens to live on: [SourceIcon]
      // scrapes this origin for the real logo.
      'siteUrl': config.baseUrl,
      'isPinned': false,
      'isEnabled': true,
      if (config.baseUrl.isNotEmpty && config.isNsfw) 'nsfw': true,
    }},
];
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if the committed .g.dart is not what these inputs generate",
    )
    args = parser.parse_args()

    entries = build_entries()
    dart = render(entries)

    if args.check:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != dart:
            print(f"OUT OF DATE: {OUT.relative_to(Path.cwd())}", file=sys.stderr)
            return 1
        print(f"OK: {OUT.relative_to(Path.cwd())} matches {len(entries)} sites")
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(dart, encoding="utf-8")
    print(f"wrote {OUT} ({len(entries)} sites, {len(dart)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
