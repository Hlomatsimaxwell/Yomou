import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/data/providers/sources_provider.dart';

/// A configured source (enabled/disabled + declared language) participating in
/// an Alternatives search.
class AltSource {
  final MangaSource source;
  final bool isEnabled;
  final String language;

  const AltSource({
    required this.source,
    required this.isEnabled,
    required this.language,
  });

  String get id => source.id;
  String get name => source.name;
}

/// One search hit for the same work on another source. The chapter count stays
/// null until the (slow) count request for that manga resolves.
class AltMangaHit {
  final Manga manga;
  final int? totalChapters;

  const AltMangaHit(this.manga, {this.totalChapters});
}

/// A single source's contribution to an Alternatives search: the hits found by
/// searching that one source, or an empty/error report.
class SourceAltResult {
  final String sourceId;
  final List<AltMangaHit> hits;
  final bool hasError;

  const SourceAltResult({
    required this.sourceId,
    this.hits = const [],
    this.hasError = false,
  });

  bool get hasHits => hits.isNotEmpty;
}

/// The list of configured (non-mock, de-duplicated) sources, with their
/// enabled state and declared language. This drives the watch-loop in the
/// screen: each source is searched independently so results appear the moment
/// that source finishes.
final configuredAltSourcesProvider = Provider<List<AltSource>>((ref) {
  final rows = ref.watch(visibleSourceRowsProvider);
  final list = <AltSource>[];
  final seen = <String>{};
  for (final row in rows) {
    final name = row['name']?.toString() ?? '';
    if (name.isEmpty || name == 'Mock Source') continue;
    final source = getSourceByName(name);
    if (seen.add(source.id)) {
      list.add(
        AltSource(
          source: source,
          isEnabled: isSourceEnabled(row),
          language: row['language']?.toString() ?? '',
        ),
      );
    }
  }
  return list;
});

/// In-memory chapter-count cache shared across sources and queries: re-editing
/// the search box or re-opening the screen never refetches counts that were
/// already loaded.
final Map<String, int> _altTotals = {};

/// Searches ONE configured source for [query] and returns its hits (with
/// chapter counts filled in from the shared cache). Each source resolves
/// independently so the UI can append rows and bump the source counter as each
/// one finishes, instead of waiting for the whole fan-out.
final sourceAlternativesProvider = FutureProvider.family<SourceAltResult, ({
  String sourceId,
  String sourceName,
  String query,
})>((ref, args) async {
  final trimmed = args.query.trim();
  if (trimmed.isEmpty) return SourceAltResult(sourceId: args.sourceId);
  final source = getSourceBySourceId(args.sourceId) ??
      getSourceByName(args.sourceName);
  try {
    final manga = await SourceCache.mangaList(
      sourceId: source.id,
      kind: 'title',
      arg: trimmed.toLowerCase(),
      page: 1,
      fetch: () => source.searchByTitle(trimmed),
    );
    final unique = <Manga>[];
    final seenIds = <String>{};
    for (final m in manga) {
      if (seenIds.add(m.id)) unique.add(m);
    }
    await _fillTotals(source, unique);
    return SourceAltResult(
      sourceId: args.sourceId,
      hits: [
        for (final m in unique)
          AltMangaHit(
            m,
            totalChapters: _altTotals['${source.id}|${m.id}'],
          ),
      ],
    );
  } catch (_) {
    return SourceAltResult(sourceId: args.sourceId, hasError: true);
  }
});

Future<void> _fillTotals(MangaSource source, List<Manga> manga) async {
  var cursor = 0;
  Future<void> worker() async {
    while (true) {
      final i = cursor++;
      if (i >= manga.length) return;
      final m = manga[i];
      final key = '${source.id}|${m.id}';
      if (_altTotals.containsKey(key)) continue;
      try {
        final total = await source
            .getTotalChapters(m.id)
            .timeout(const Duration(seconds: 6));
        _altTotals[key] = total;
      } catch (_) {}
    }
  }

  await Future.wait([for (var k = 0; k < 4; k++) worker()]);
}

/// Simple deterministic relevance score for "Best match" ordering: prefer exact
/// (case-insensitive) title equality, then title starts-with the query, then
/// earliest occurrence of the query within the title, then short titles first.
double relevanceScore(Manga m, String query) {
  final title = m.title.toLowerCase();
  final q = query.toLowerCase();
  if (title == q) return 0;
  if (title.startsWith(q)) return 1;
  final idx = title.indexOf(q);
  if (idx >= 0) return 2 + idx / 100.0;
  return 3;
}