# Source catalog generators

The bundled generic sources (Madara + MangaThemesia + ZeistManga) are generated
from local, gitignored `.data/` JSON. The generated `.g.dart` files are
**committed** — a commit ships the Dart, not the JSON.

> Every `lib/data/sources/catalog/*.g.dart` file says "do not edit by hand".
> Change the inputs or the generator, then regenerate.

## Commands

From the repo root:

```bash
# Regenerate all catalogs from current .data/ inputs.
python3 tool/catalog/gen_madara_catalog.py
python3 tool/catalog/gen_manga_themesia_catalog.py
python3 tool/catalog/gen_zeistmanga_catalog.py

# Verify the committed output matches the inputs (safe in CI / pre-commit).
python3 tool/catalog/gen_madara_catalog.py --check
python3 tool/catalog/gen_manga_themesia_catalog.py --check
python3 tool/catalog/gen_zeistmanga_catalog.py --check
```

Then, because the payload feeds the runtime source registry:

```bash
flutter test test/catalog_integrity_test.dart
flutter analyze
```

`catalog_common.py` holds the language-code table and host normalisation shared
by all three generators. Teach a new language code there once.

## Inputs

All under `.data/` (local only, not in git):

| File | Used by | Contents |
|---|---|---|
| `engines.json` | all three | extension engines: `theme`, and `sources[]` with `id`, `language`, `homeUrl` |
| `sources_catalog.json` | all three | keyed by bare host: `name`, `langs`, `icon`, `nsfw` |
| `madara_validation.json` | Madara only | per-host sweep result: `verdict`, `listingPath`, … |

The `.data/` host key is the bare host (`example.com`), while `engines.json`
keeps the URL the extension actually talks to (which may include `www.` or a
path). `bare_host()` in `catalog_common.py` bridges the two.

## Adding a site

### MangaThemesia (one generic driver already exists)

1. Add a row to `sources_catalog.json` for the bare host: correct `name`,
   `langs`, `icon`, `nsfw`.
2. Add an engine to `engines.json` with `"theme": "mangathemesia"` and a source
   with the real `id`, `language` and `homeUrl`. **Only the engine's first source
   is emitted** — a multi-language engine with several sources still yields one
   row, so add a separate engine per language you want shipped.
3. Run `python3 tool/catalog/gen_manga_themesia_catalog.py`.
4. Confirm the new name resolves (the integrity test covers this), then rebuild.

No registry edit is needed: `sources_provider.dart` already spreads
`catalogMangaThemesiaSourceRows` into the defaults and resolves every generated
id/name. On a fresh install the row is enabled; existing installs keep their
saved order/flags and pick up new rows as enabled.

### ZeistManga (Blogger feeds, one generic driver)

1. Add the usual `sources_catalog.json` row and a `theme: zeistmanga` engine.
2. If the site publishes catalogue posts under a label other than `Series`, or
   needs a special reader-image selector, add an entry to `OVERRIDES` keyed by
   the lower-cased site name in `gen_zeistmanga_catalog.py`.
3. Run `python3 tool/catalog/gen_zeistmanga_catalog.py`. Dat-Gar Scan is
   intentionally skipped: it keeps its older hand-written source, which owns
   the source id used by existing favorites.

### Madara

1. Ensure the host has a `sources_catalog.json` row and a `theme: madara` engine
   whose source `homeUrl` matches the host.
2. In `madara_validation.json`, set the host's `verdict` to `ok` and give it the
   right `listingPath`. Only `ok` hosts are emitted; hosts in `SKIP_HOSTS` in
   `gen_madara_catalog.py` (already shipped as hand-written sources, or known
   broken on-device) are excluded.
3. Run `python3 tool/catalog/gen_madara_catalog.py`.

### Other engines

Sites with any other theme (`zeistmanga`, `comiciviewer`, `gigaviewer`, …) or no
theme cannot ride these drivers. They need a hand-written `MangaSource` class in
`lib/data/sources/`, plus cases in both `getSourceByName` and
`getSourceBySourceId` and a row in `SourcesNotifier.defaultSources` in
`sources_provider.dart`.

## Gotchas

- `nsfw` in the JSON is a content-filter flag, **not** an enable switch. Runtime
  enable/disable is a preference keyed by source name.
- `getSourceByName` falls back to MangaDex for an unknown name, so a name
  mismatch in a generated row would silently show the wrong source. The
  integrity test asserts every generated name resolves to its own id.
- The generators are deterministic: regenerating with unchanged inputs produces
  a byte-identical file, so `--check` is a reliable guard.
