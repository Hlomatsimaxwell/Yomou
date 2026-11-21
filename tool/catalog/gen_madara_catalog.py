#!/usr/bin/env python3
"""Generate lib/data/sources/catalog/madara_catalog.g.dart.

Input (all local, gitignored under .data/):
  sources_catalog.json  - deduped sites (name/icon/lang/nsfw)
  madara_validation.json - go/no-go sweep result per host

Only hosts whose listing, detail, chapter list and reader page all responded
are emitted, so every bundled source has been seen working at least once.
"""
import argparse
import json
import sys
from pathlib import Path

from catalog_common import CATALOG_DIR, DATA, bare_host, language_label

OUT = CATALOG_DIR / "madara_catalog.g.dart"

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
    "cat-300.com",  # covers 404 and detail AJAX failing on-device
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if the committed .g.dart is not what these inputs generate",
    )
    args = parser.parse_args()

    validation = json.load(open(DATA / "madara_validation.json"))
    catalog = {c["host"]: c for c in json.load(open(DATA / "sources_catalog.json"))}

    # The extension index declares each site's home URL, which is the host the
    # extension itself talks to. Keeping it verbatim matters: the catalogue's
    # deduped keys drop `www.`, but the site may canonicalise to it, and a
    # base URL on the wrong host makes every relative link resolve wrong.
    declared = {}
    for ext in json.load(open(DATA / "engines.json")):
        if ext.get("theme") != "madara":
            continue
        for source in ext.get("sources", []):
            url = (source.get("homeUrl") or "").rstrip("/")
            if not url:
                continue
            declared.setdefault(bare_host(url), url)

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
        entries.append({
            "id": host.replace("-", "_"),
            "name": name,
            "baseUrl": declared.get(host, f"https://{host}"),
            "iconUrl": cat.get("icon") or "",
            "language": language_label(cat.get("langs")),
            "nsfw": bool(cat.get("nsfw")),
            # The archive path differs per site: stock Madara serves /manga/,
            # some rename the post type (/comic/, /series/) and some point the
            # homepage at the archive. The sweep recorded which one rendered
            # cards, so Explore's listing is not an empty page.
            "popularPath": row.get("listingPath") or "?m_orderby=views",
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

/// The same sites keyed by id, which is what a stored manga row carries as its
/// `sourceId`.
final Map<String, MadaraSiteConfig> catalogMadaraById = {{
  for (final config in catalogMadaraConfigs) config.id: config,
}};

/// Source-list rows for the catalog. Enabled by default; a source the user
/// never uses can be switched off in Manage sources.
List<Map<String, dynamic>> get catalogSourceRows => [
  for (final raw in jsonDecode(kCatalogMadaraJson) as List)
    {{
      'name': (raw as Map)['name'] as String,
      'language': raw['language'] as String,
      'iconUrl': raw['iconUrl'] as String? ?? '',
      // The site itself, not the CDN its icon happens to live on: [SourceIcon]
      // scrapes this origin for the real logo.
      'siteUrl': raw['baseUrl'] as String,
      'isPinned': false,
      'isEnabled': true,
      if (raw['nsfw'] == true) 'nsfw': true,
    }},
];

MadaraSiteConfig _configFrom(Map<String, dynamic> raw) => MadaraSiteConfig(
  id: raw['id'] as String,
  name: raw['name'] as String,
  baseUrl: raw['baseUrl'] as String,
  language: raw['language'] as String,
  iconUrl: raw['iconUrl'] as String? ?? '',
  popularPath: raw['popularPath'] as String? ?? '?m_orderby=views',
  // Madara lazy-loads both covers and reader pages, so the real URL lives in
  // data-src; the engine falls back to src for sites that do not.
  coverAttr: 'data-src',
  mangaCardSelector: '.page-item-detail, .c-tabs-item__content, .manga-item',
  // Madara sites disagree on whether the chapter list is nested in ul.main,
  // and some mark reader images with a class instead of the id.
  chapterListSelector: 'ul.main li.wp-manga-chapter, li.wp-manga-chapter, .wp-manga-chapter, .listing-chapters_wrap li',
  readerImageSelector: '.wp-manga-chapter-img, #reading-content img, .reading-content img',
);
'''
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
