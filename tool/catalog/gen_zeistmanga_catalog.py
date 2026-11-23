#!/usr/bin/env python3
"""Generate lib/data/sources/catalog/zeistmanga_catalog.g.dart.

Input (all local, gitignored under .data/):
  engines.json         - extension engines; every one with theme=zeistmanga
                         contributes a site
  sources_catalog.json - deduped site names, icons, languages and nsfw flags

One generic [ZeistMangaSource] serves every bundled site, so adding a site
means adding its rows to the two JSON files and re-running this script. The
output is committed; the .data/ files are not.

Usage:
  python3 tool/catalog/gen_zeistmanga_catalog.py
  python3 tool/catalog/gen_zeistmanga_catalog.py --check   # CI / pre-commit
"""
import argparse
import json
import sys

from catalog_common import CATALOG_DIR, DATA, ROOT, bare_host, language_label

OUT = CATALOG_DIR / "zeistmanga_catalog.g.dart"

# Dat-Gar Scan keeps its hand-written DatgarScanlationSource (older favorites
# carry that source id), so the generic catalog must not register it a second
# time. Everything else in the theme is served by the generic parser.
SKIP_NAMES = {"dat-gar scan"}

# Kotatsu's per-site subclasses override only a few fields. Keeping them here
# means the generated Dart config carries the override instead of hard-coding
# host checks in the parser.
OVERRIDES = {
    "galax scans": {"mangaCategory": "Recentes"},
    "manhatok": {"pageSelector": "#seoneurons-target img"},
    "temaki mangás": {"pageSelector": "#reader div.separator img"},
}


def build_entries():
    engines = json.load(open(DATA / "engines.json", encoding="utf-8"))
    catalog = {
        row["host"]: row
        for row in json.load(open(DATA / "sources_catalog.json", encoding="utf-8"))
    }

    entries = []
    for engine in engines:
        if engine.get("theme") != "zeistmanga":
            continue
        sources = engine.get("sources") or []
        if not sources:
            continue
        source = sources[0]  # one row per engine; theme sites are single-language
        url = (source.get("homeUrl") or "").rstrip("/")
        if not url:
            continue
        host = bare_host(url)
        site = catalog.get(host)
        if not site:
            print(f"warning: no sources_catalog.json row for {host}", file=sys.stderr)
            continue
        name = site["name"].strip() or host
        if name.lower() in SKIP_NAMES:
            continue
        entry = {
            "id": source["id"],
            "name": name,
            "baseUrl": url,
            "langCode": source.get("language"),
            "language": language_label(site.get("langs")),
            "iconUrl": site.get("icon") or "",
            "nsfw": bool(site.get("nsfw")),
        }
        entry.update(OVERRIDES.get(name.lower(), {}))
        entries.append(entry)

    entries.sort(key=lambda entry: entry["name"].lower())
    return entries


def render(entries):
    payload = json.dumps(entries, ensure_ascii=False, separators=(",", ":"))
    return f'''// GENERATED FILE - do not edit by hand.
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
const String kCatalogZeistMangaJson = r\'\'\'{payload}\'\'\';

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
final Map<String, ZeistMangaSiteConfig> catalogZeistMangaByName = {{
  for (final config in catalogZeistMangaConfigs) config.name: config,
}};

/// The same sites keyed by id, which is what a stored manga row carries as its
/// `sourceId`.
final Map<String, ZeistMangaSiteConfig> catalogZeistMangaById = {{
  for (final config in catalogZeistMangaConfigs) config.id: config,
}};

/// Source-list rows for the catalog.
List<Map<String, dynamic>> get catalogZeistMangaSourceRows => [
  for (final config in catalogZeistMangaConfigs)
    {{
      'name': config.name,
      'language': config.language,
      'iconUrl': config.iconUrl,
      // The site itself, not the CDN its icon happens to live on.
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
            print(f"OUT OF DATE: {OUT.relative_to(ROOT)}", file=sys.stderr)
            return 1
        print(f"OK: {OUT.relative_to(ROOT)} matches {len(entries)} sites")
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(dart, encoding="utf-8")
    print(f"wrote {OUT} ({len(entries)} sites, {len(dart)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
