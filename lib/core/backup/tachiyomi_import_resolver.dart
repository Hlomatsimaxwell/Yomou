import 'package:yomou/core/backup/tachiyomi_backup.dart';
import 'package:yomou/core/utils/concurrent.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_source.dart';

/// Fills in a Tachiyomi import's missing entries by searching the sources the
/// reader actually has for the same title.
///
/// A Mihon backup commonly holds titles from extensions Yomou doesn't ship. The
/// codec keeps those as [TachiyomiMissingManga] instead of dropping them; here
/// each one is searched (by title) across [sources] and, on a confident match,
/// re-bound to that source's copy of the work. Favorite status and the
/// last-read chapter number carry over; the per-chapter ids and bookmarks do
/// not, because they belong to the original site.
///
/// Entries with no match are added to [TachiyomiImportResult.skippedMangas]
/// (reason [TachiyomiSkippedReason.unsupportedSource]) so the result screen can
/// tell the reader exactly which titles failed.
Future<TachiyomiImportResult> resolveTachiyomiMissing(
  TachiyomiImportResult parsed,
  List<MangaSource> sources, {
  void Function(int done, int total)? onProgress,
  int maxConcurrent = 2,
  Duration searchTimeout = const Duration(seconds: 8),
}) async {
  final missing = parsed.missingMangas;
  if (missing.isEmpty) return parsed;

  final recovered = <TachiyomiImportedManga>[];
  final failed = <TachiyomiSkippedManga>[...parsed.skippedMangas];

  var completed = 0;
  final total = missing.length;
  onProgress?.call(0, total);

  var cursor = 0;
  Future<void> worker() async {
    while (true) {
      final index = cursor++;
      if (index >= missing.length) return;
      final entry = missing[index];
      final match = await _findMatch(entry.title, sources, searchTimeout);
      if (match != null) {
        recovered.add(TachiyomiImportedManga(
          mangaId: match.id,
          title: match.title,
          coverUrl: match.coverUrl,
          sourceId: match.sourceId,
          lastReadChapter: entry.lastReadChapter,
          lastReadAt: entry.lastReadAt,
          isFavorite: entry.isFavorite,
          bookmarks: const <Map<String, dynamic>>[],
        ));
      } else {
        failed.add(TachiyomiSkippedManga(
          title: entry.title,
          url: entry.url,
          sourceName: entry.sourceName,
          reason: TachiyomiSkippedReason.unsupportedSource,
        ));
      }
      completed++;
      onProgress?.call(completed, total);
    }
  }

  // A few titles are searched at once so a long backup finishes in a sensible
  // time without firing every source's request at the phone at the same moment.
  await Future.wait([
    for (var i = 0; i < maxConcurrent && i < missing.length; i++) worker(),
  ]);

  return TachiyomiImportResult(
    mangas: parsed.mangas,
    recoveredMangas: recovered,
    skippedMangas: failed,
  );
}

/// Searches every source for [title] and returns the single best match, or null
/// when nothing lines up. Each source is queried concurrently and the fan-out
/// stops early once one returns an acceptable match, so a title only one source
/// carries isn't held up by the slowest one.
Future<Manga?> _findMatch(
  String title,
  List<MangaSource> sources,
  Duration timeout,
) async {
  final query = title.trim();
  if (query.isEmpty) return null;

  final futures = <Future<Manga?>>[
    for (final source in sources)
      Future.sync(() => source.searchByTitle(query)).timeout(timeout).then<Manga?>(
            (results) => _bestIn(results, query),
            onError: (_, _) => null,
          ),
  ];

  final settled = await waitFastest(
    futures,
    deadline: timeout,
    grace: const Duration(seconds: 3),
    hasResult: (results) =>
        results.any((m) => m != null && _titleRank(query, m.title) <= 2),
  );

  Manga? best;
  var bestRank = 99;
  for (final m in settled) {
    if (m == null) continue;
    final rank = _titleRank(query, m.title);
    if (rank < bestRank) {
      bestRank = rank;
      best = m;
    }
  }
  return bestRank <= 2 ? best : null;
}

Manga? _bestIn(List<Manga> results, String query) {
  Manga? best;
  var bestRank = 99;
  for (final m in results) {
    final rank = _titleRank(query, m.title);
    if (rank < bestRank) {
      bestRank = rank;
      best = m;
    }
  }
  return bestRank <= 2 ? best : null;
}

/// How well [candidate] matches [query]: 0 exact, 1 near-identical (token
/// overlap >= 0.8), 2 one title contains the other, 99 no usable match.
///
/// Deliberately strict: a wrong re-bind silently attaches the reader's progress
/// to an unrelated title, which is worse than reporting the entry as failed.
int _titleRank(String query, String candidate) {
  final a = _normalize(query);
  final b = _normalize(candidate);
  if (a.isEmpty || b.isEmpty) return 99;
  if (a == b) return 0;

  final ta = a.split(' ').toSet();
  final tb = b.split(' ').toSet();
  final inter = ta.intersection(tb).length;
  final union = ta.union(tb).length;
  if (union > 0 && inter / union >= 0.8) return 1;

  final shorter = a.length <= b.length ? a : b;
  if (shorter.length >= 4 && (a.contains(b) || b.contains(a))) return 2;
  return 99;
}

/// Lowercases and reduces a title to space-separated alphanumerics so casing,
/// punctuation and extra spacing don't defeat equality.
String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();
