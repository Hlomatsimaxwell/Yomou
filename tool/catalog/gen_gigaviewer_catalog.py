#!/usr/bin/env python3
"""Generate lib/data/sources/catalog/gigaviewer_catalog.g.dart.

Input (all local, gitignored under .data/):
  engines.json         - every engine with theme=gigaviewer (one site each)
  sources_catalog.json - deduped site names, icons, languages and nsfw flags

Plus the committed `gigaviewer_sites.json` next to this script, which holds the
per-site serial-group ids and filter lists extracted from the upstream
keiyoushi/extensions-source `gigaviewer` multisrc subclasses. Keeping those ids
in a reviewable JSON input means the Dart parser has no host-specific checks.

One generic [GigaViewerSource] serves every bundled site, so adding a site
means adding its rows to the JSON files and re-running this script. The output
is committed; the .data/ files are not.

Usage:
  python3 tool/catalog/gen_gigaviewer_catalog.py
  python3 tool/catalog/gen_gigaviewer_catalog.py --check   # CI / pre-commit
"""
import argparse
import json
import sys
from pathlib import Path

from catalog_common import CATALOG_DIR, DATA, ROOT, bare_host, language_label

OUT = CATALOG_DIR / "gigaviewer_catalog.g.dart"
SITES = Path(__file__).parent / "gigaviewer_sites.json"


def build_entries():
    engines = json.load(open(DATA / "engines.json", encoding="utf-8"))
    catalog = {
        row["host"]: row
        for row in json.load(open(DATA / "sources_catalog.json", encoding="utf-8"))
    }
    overrides = json.load(open(SITES, encoding="utf-8"))

    entries = []
    for engine in engines:
        if engine.get("theme") != "gigaviewer":
            continue
        sources = engine.get("sources") or []
        if not sources:
            continue
        source = sources[0]  # one row per engine; these sites are single-language
        url = (source.get("homeUrl") or "").rstrip("/")
        if not url:
            continue
        host = bare_host(url)
        site = catalog.get(host)
        if not site:
            print(f"warning: no sources_catalog.json row for {host}", file=sys.stderr)
            continue
        name = site["name"].strip() or host
        entry = {
            "id": source["id"],
            "name": name,
            "baseUrl": url,
            "langCode": source.get("language"),
            "language": language_label(site.get("langs")),
            "iconUrl": site.get("icon") or "",
            "nsfw": bool(site.get("nsfw")),
        }
        override = overrides.get(host)
        if override is None:
            print(f"warning: no gigaviewer_sites.json row for {host}", file=sys.stderr)
        else:
            entry.update(override)
        entries.append(entry)

    entries.sort(key=lambda entry: entry["name"].lower())
    return entries


def render(entries):
    payload = json.dumps(entries, ensure_ascii=False, separators=(",", ":"))
    return f"""// GENERATED FILE - do not edit by hand.
//
// Built from .data/engines.json (theme: gigaviewer),
// .data/sources_catalog.json (icons + nsfw flags) and the committed
// tool/catalog/gigaviewer_sites.json (serial-group ids + filter lists from
// the upstream keiyoushi multisrc subclasses). Every GigaViewer engine shares
// the same GraphQL viewer, so all of these sites are served by the generic
// [GigaViewerSource] instead of one hand-written class per site.
//
// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:yomou/data/models/gigaviewer_site_config.dart';

/// Compact catalog payload: id, name, baseUrl, langCode, language, iconUrl,
/// nsfw, seriesListIds, filterOptions and any per-site mode overrides.
const String kCatalogGigaViewerJson = r'''{payload}''';

List<GigaViewerSiteConfig>? _configs;

/// Every bundled GigaViewer site, parsed once.
List<GigaViewerSiteConfig> get catalogGigaViewerConfigs => _configs ??= [
  for (final raw in jsonDecode(kCatalogGigaViewerJson) as List)
    GigaViewerSiteConfig.fromJson((raw as Map).cast<String, dynamic>()),
];

/// Sites keyed by display name, used by registry rows and `getSourceByName`.
final Map<String, GigaViewerSiteConfig> catalogGigaViewerByName = {{
  for (final config in catalogGigaViewerConfigs) config.name: config,
}};

/// Sites keyed by stored `sourceId`.
final Map<String, GigaViewerSiteConfig> catalogGigaViewerById = {{
  for (final config in catalogGigaViewerConfigs) config.id: config,
}};

/// Source-list rows for the catalog.
List<Map<String, dynamic>> get catalogGigaViewerSourceRows => [
  for (final config in catalogGigaViewerConfigs)
    {{
      'name': config.name,
      'language': config.language,
      'iconUrl': config.iconUrl,
      'siteUrl': config.baseUrl,
      'isPinned': false,
      'isEnabled': true,
      if (config.baseUrl.isNotEmpty && config.isNsfw) 'nsfw': true,
    }},
];
"""


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
