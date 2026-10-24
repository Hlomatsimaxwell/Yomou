import 'dart:convert';
import 'dart:math' as math;
import 'dart:math';

/// The picking decisions behind the suggested-manga notification, ported from
/// Kotatsu-Redo's `SuggestionRanking` (and, for the vocabulary math, its
/// parsers' `String.almostEquals`). Kept free of IO and Flutter here so every
/// rule can be tested on its own — exactly the shape the reference keeps.
///
/// Frequency alone is why a naive suggestions model always crowns `action`:
/// reading a lot of it says little when nearly everything the app has stored
/// carries the same tag. The reference measures taste against what the reader
/// reads, weighted by how rare each tag is across everything the app has seen
/// — TF-IDF on the device.

/// `SuggestionRanking.normalizeTag`: tags compared case-insensitively, trimmed.
/// `Action`, ` action ` and `ACTION` are one tag.
String normalizeTag(String title) {
  final normalized = title.trim().toLowerCase();
  // NFKC-less whitespace from scraped HTML: the seed's inner spaces survive,
  // but an invisible separator should never split a match.
  return normalized.replaceAll('\u00a0', ' ');
}

/// The reference's `levenshteinDistance`: classic edit distance over the two
/// whole strings.
int levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final current = [i + 1];
    for (var j = 0; j < b.length; j++) {
      final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      current.add(min(
        min(current[j] + 1, previous[j + 1] + 1),
        previous[j] + cost,
      ));
    }
    previous = current;
  }
  return previous[b.length];
}

/// `String.almostEquals` from the parsers library, verbatim: the edit distance
/// between the lowercased strings over their *average* length, matched when
/// strictly under [threshold]. `0 = exact match` there; at the worker's
/// `TAG_EQ_THRESHOLD = 0.4`, `shounen` still finds `Shonen` and even
/// `shounen ai`, while `action` never matches `comedy`.
bool almostEquals(
  String a,
  String other, {
  double threshold = tagEqualityThreshold,
}) {
  if (threshold <= 0) {
    return a.toLowerCase() == other.toLowerCase();
  }
  final span = (a.length + other.length) / 2;
  if (span == 0) return true;
  final diff =
      levenshteinDistance(a.toLowerCase(), other.toLowerCase()) / span;
  return diff < threshold;
}

/// `SuggestionsWorker.TAG_EQ_THRESHOLD`.
const tagEqualityThreshold = 0.4;

/// How common each tag is across everything the app has stored — browsed
/// lists, opened manga, suggestions, every source. That is the background a
/// reader's taste is measured against: the reference's `TagStatistics`.
///
/// Counted from the `manga` table's rows (the same corpus the app's tag
/// badge and the Suggestions feed's taste model already read from), cached
/// per scan: the digest's one sweep builds it once.
class TagStatistics {
  TagStatistics._(this._documentFrequency, this.total);

  final Map<String, int> _documentFrequency;

  /// How many stored manga carry any tag at all (the corpus size, not the
  /// number of tags — `ln(total)` needs the document count).
  final int total;

  /// Builds the snapshot over [rows], each row's `tags` cell a JSON list the
  /// way every write path stores it.
  factory TagStatistics.fromRows(List<Map<String, dynamic>> rows) {
    final frequency = <String, int>{};
    var total = 0;
    for (final row in rows) {
      final tags = _decodeTags(row['tags']);
      if (tags.isEmpty) continue;
      total += 1;
      for (final title in tags) {
        final key = normalizeTag(title);
        if (key.isEmpty) continue;
        frequency[key] = (frequency[key] ?? 0) + 1;
      }
    }
    return TagStatistics._(frequency, total);
  }

  static List<String> _decodeTags(Object? raw) {
    if (raw is! String || raw.isEmpty || raw == '[]') return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final e in decoded) if (e is String) e];
    } on Exception {
      return const [];
    }
  }

  /// How many stored manga carry [title].
  int frequency(String title) =>
      _documentFrequency[normalizeTag(title)] ?? 0;

  /// Inverse document frequency, smoothed so an unseen tag is *rare* rather
  /// than infinite — the reference's `Snapshot.rarity`, the same formula:
  /// `ln((total + 1) / (frequency + 1)) + 1`.
  double rarity(String title) =>
      math.log((total + 1) / (frequency(title) + 1)) + 1.0;
}

/// Under a tenth read…
const droppedMaxPercent = 0.1;

/// …and untouched this long counts as left, not merely paused.
const droppedAfter = Duration(days: 21);

/// Opened, barely read and left for weeks. [percent] is the reading progress
/// from history in `0..1`, null when unknown — and unknown is not evidence of
/// anything, so it is never dropped. Two weeks of a daily-release title is a
/// pause; three weeks of a 2%-read title is the reader turning away.
bool isDropped(double? percent, DateTime? updatedAt, DateTime now) {
  if (percent == null || updatedAt == null) return false;
  return percent >= 0 && percent <= droppedMaxPercent &&
      now.difference(updatedAt) > droppedAfter;
}

/// The reader's most telling tags rather than their most frequent, most
/// telling first — the reference's `SuggestionRanking.distinctiveTags`.
///
/// Frequency alone always crowns `action` or `fantasy`, and searching a source
/// for those returns its best-sellers rather than anything close to this
/// reader. Ranking by [TagStatistics.rarity] alongside the count fixes that:
/// frequent in what the reader reads *and* rare in everything else. A tag on
/// only one of the reader's manga comes after every recurring one however rare
/// it is — one title's odd tag is not a taste.
///
/// [seedTags] carries one entry per manga holding the tag; [rarity] is the
/// inverse document frequency; returns original titles, as the sources spell
/// them.
List<String> distinctiveTags(
  List<String> seedTags,
  double Function(String) rarity,
  int limit,
) {
  final counts = <String, (String, int)>{};
  for (final title in seedTags) {
    final key = normalizeTag(title);
    if (key.isEmpty) continue;
    final existing = counts[key];
    counts[key] = (existing?.$1 ?? title, (existing?.$2 ?? 0) + 1);
  }
  final recurring = <(String, int)>[];
  final once = <(String, int)>[];
  for (final entry in counts.values) {
    (entry.$2 >= 2 ? recurring : once).add(entry);
  }
  List<String> rank(List<(String, int)> tags) {
    final sorted = tags.toList()
      ..sort((a, b) {
        final aScore = a.$2 * rarity(a.$1);
        final bScore = b.$2 * rarity(b.$1);
        return bScore.compareTo(aScore);
      });
    return [for (final e in sorted) e.$1];
  }
  return [...rank(recurring), ...rank(once)].take(limit).toList();
}

/// How closely a candidate echo the reader's ranked tags — the worker's
/// `computeRelevance`. Each of the candidate's tags counts by how early it
/// sits in [rankedTags] (matched through [almostEquals], tags compared across
/// sources never quite spell alike), scaled against the maximum possible
/// weight, and squared so a near-full echo pulls far ahead of a token one.
double computeRelevance(List<String> mangaTags, List<String> rankedTags) {
  if (rankedTags.isEmpty || mangaTags.isEmpty) return 0;
  final n = rankedTags.length;
  final m = mangaTags.length;
  final maxWeight = (n + n + 1 - m) * m / 2.0;
  var weight = 0.0;
  for (final tag in mangaTags) {
    final index = inexactIndexOf(rankedTags, tag, tagEqualityThreshold);
    if (index >= 0) weight += n - index;
  }
  if (maxWeight <= 0) return 0;
  return math.pow(weight / maxWeight, 2.0).toDouble();
}

/// `inexactIndexOf`: the earliest ranked position whose tag sits within
/// [threshold] of [element].
int inexactIndexOf(List<String> rankedTags, String element, double threshold) {
  for (var i = 0; i < rankedTags.length; i++) {
    if (almostEquals(rankedTags[i], element, threshold: threshold)) {
      return i;
    }
  }
  return -1;
}

/// The reference's notification pick: one random manga from the best third of
/// the ranked suggestions — the same index arithmetic as
/// `Random.nextInt(0, (suggestions.size / 3).coerceAtLeast(1))`, an upper
/// bound that is exclusive and never empty for even one suggestion.
///
/// Returns -1 when there is nothing to pick from.
int pickAnnounceIndex(int size, Random rng) {
  if (size <= 0) return -1;
  final bound = max(size ~/ 3, 1);
  return rng.nextInt(bound);
}
