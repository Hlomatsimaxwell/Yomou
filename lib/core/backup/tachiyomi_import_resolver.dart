import 'package:yomou/core/backup/tachiyomi_backup.dart';
import 'package:yomou/core/utils/concurrent.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/data/models/manga_translation.dart';

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
///
/// [preferredLanguages] holds the reader's content languages (display names
/// such as `"English"`). When a title is carried by more than one source, a
/// match in one of those languages is preferred; a language the reader did not
/// pick is only used when nothing in their languages has the title, so a rescue
/// never loses an entry it could otherwise have kept. An empty set means the
/// reader has no language preference and the best title match wins outright.
Future<TachiyomiImportResult> resolveTachiyomiMissing(
  TachiyomiImportResult parsed,
  List<MangaSource> sources, {
  Set<String> preferredLanguages = const <String>{},
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
      final match = await _findMatch(
        entry.title,
        sources,
        searchTimeout,
        preferredLanguages,
      );
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
///
/// When [preferredLanguages] is non-empty, a same-language match is preferred:
/// if the fastest acceptable match is in another language, the fan-out gets a
/// short extra window to hear from a preferred source before falling back. The
/// window only opens when no preferred match has arrived yet, so the common
/// case (already preferred, or no preference set) pays nothing.
Future<Manga?> _findMatch(
  String title,
  List<MangaSource> sources,
  Duration timeout,
  Set<String> preferredLanguages,
) async {
  final query = title.trim();
  if (query.isEmpty) return null;

  final futures = <Future<_Candidate?>>[
    for (final source in sources)
      Future.sync(() => source.searchByTitle(query)).timeout(timeout).then<_Candidate?>(
            (results) => _bestIn(results, query, source, preferredLanguages),
            onError: (_, _) => null,
          ),
  ];

  final settled = await waitFastest(
    futures,
    deadline: timeout,
    grace: const Duration(seconds: 3),
    hasResult: (candidates) => candidates.any((c) => c != null && c.rank <= 2),
  );

  var matches = settled.whereType<_Candidate>().toList();

  if (matches.isNotEmpty &&
      preferredLanguages.isNotEmpty &&
      !matches.any((c) => c.preferred)) {
    final late = await waitFastest(
      futures,
      deadline: const Duration(seconds: 2),
      grace: Duration.zero,
      hasResult: (candidates) =>
          candidates.any((c) => c != null && c.rank <= 2 && c.preferred),
    );
    matches = [...matches, ...late.whereType<_Candidate>()];
  }

  if (matches.isEmpty) return null;

  final preferred = matches.where((c) => c.preferred).toList();
  final pool = preferred.isNotEmpty ? preferred : matches;
  var best = pool.first;
  for (final candidate in pool) {
    if (candidate.rank < best.rank) best = candidate;
  }
  return best.manga;
}

/// One source's best acceptable answer for a query, tagged with whether the
/// source publishes in one of the reader's languages.
class _Candidate {
  const _Candidate(this.manga, this.rank, this.preferred);

  final Manga manga;
  final int rank;
  final bool preferred;
}

_Candidate? _bestIn(
  List<Manga> results,
  String query,
  MangaSource source,
  Set<String> preferredLanguages,
) {
  Manga? best;
  var bestRank = 99;
  for (final m in results) {
    final rank = _titleRank(query, m.title);
    if (rank < bestRank) {
      bestRank = rank;
      best = m;
    }
  }
  if (best == null || bestRank > 2) return null;
  return _Candidate(best, bestRank, _languageWanted(source, preferredLanguages));
}

/// Whether [source] publishes in one of the reader's [preferredLanguages]
/// (display names such as "English"). An empty set means the reader has no
/// language preference, so every source counts as preferred and the title match
/// is decided on its own.
bool _languageWanted(MangaSource source, Set<String> preferredLanguages) {
  if (preferredLanguages.isEmpty) return true;
  final wanted = preferredLanguages.map((l) => l.trim().toLowerCase()).toSet();
  final tag = MangaLanguage.label(source.languageCode).toLowerCase();
  if (wanted.contains(tag)) return true;
  // Regional spellings ("Portuguese (Brazil)") count as their base language,
  // the same way the Explore filter treats them.
  final paren = tag.indexOf(' (');
  return paren > 0 && wanted.contains(tag.substring(0, paren));
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
