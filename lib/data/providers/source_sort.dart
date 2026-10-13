/// The orders Settings > Manga sources > Sorting order can put the source list
/// in.
///
/// Values are persisted verbatim in `CacheSettings.sourceSortOrder`, so keep
/// them stable: an unknown string falls back to [manual].
abstract final class SourceSortOrder {
  static const manual = 'manual';
  static const name = 'name';
  static const popular = 'popular';
  static const lastUsed = 'lastUsed';
  static const popularReliable = 'popularReliable';

  /// The order the settings dialog offers the orders in.
  static const values = [name, popular, manual, lastUsed, popularReliable];
}

/// Curated popularity of Yomou's source families, most popular first.
///
/// Sources are a hand-picked built-in list, so there is no live popularity
/// signal to read; this is the ranking every "Popular" order is built from. It
/// ranks *families*, not rows: the MangaFire/MangaBall/MangaDex language
/// variants share their family's slot and are tie-broken by name. A family the
/// registry adds later lands after these until it is ranked here.
const List<String> kSourcePopularityOrder = [
  'MangaDex',
  'MangaFire',
  'Mangago',
  'MangaBat',
  'MangaPill',
  'WeebCentral',
  'Atsumaru',
  'Asura Scans',
  'MangaKatana',
  'MangaTown',
  'MangaBall',
  'Mgeko',
  'ManhuaPlus',
  'Flame Scans',
  'Arenascan',
  'Like Manga',
  'Manhwa18',
  'SeiManga',
  'Manganato',
];

/// Families whose browse cannot be served by a plain request, so they are the
/// ones "Popular & reliable" pushes down: a VRF token (MangaFire), an in-page
/// WebView POST (MangaBall), or a Cloudflare challenge (Mangago, Manganato).
const Set<String> kSourceUnreliableFamilies = {
  'MangaFire',
  'MangaBall',
  'Mangago',
  'Manganato',
};

String _nameOf(Map<String, dynamic> row) => (row['name'] as String?) ?? '';

/// The family a source row belongs to: the ranked family [name] equals or
/// extends with a language suffix, so "MangaFire Portuguese Brazil" resolves to
/// "MangaFire" while "MangaPill" stays itself. An unranked name is its own
/// family.
String sourceFamily(String name) {
  for (final family in kSourcePopularityOrder) {
    if (name == family || name.startsWith('$family ')) return family;
  }
  return name;
}

int _popularityRank(String name) {
  final index = kSourcePopularityOrder.indexOf(sourceFamily(name));
  // Unranked families sort after every ranked one, in a stable spot.
  return index < 0 ? kSourcePopularityOrder.length : index;
}

bool _isUnreliable(String name) =>
    kSourceUnreliableFamilies.contains(sourceFamily(name));

int _byName(Map<String, dynamic> a, Map<String, dynamic> b) {
  final an = _nameOf(a).toLowerCase();
  final bn = _nameOf(b).toLowerCase();
  final c = an.compareTo(bn);
  // Case-insensitive first, then exact, so the order never depends on sort
  // stability for names that differ only in case.
  return c != 0 ? c : _nameOf(a).compareTo(_nameOf(b));
}

int _byPopularity(Map<String, dynamic> a, Map<String, dynamic> b) {
  final c =
      _popularityRank(_nameOf(a)).compareTo(_popularityRank(_nameOf(b)));
  return c != 0 ? c : _byName(a, b);
}

int _compareRows(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
  String order,
  Map<String, int> lastUsed,
) {
  switch (order) {
    case SourceSortOrder.name:
      return _byName(a, b);
    case SourceSortOrder.popular:
      return _byPopularity(a, b);
    case SourceSortOrder.lastUsed:
      // Most recently opened first; never-opened rows fall back to name so the
      // tail is not arbitrary.
      final la = lastUsed[_nameOf(a)] ?? 0;
      final lb = lastUsed[_nameOf(b)] ?? 0;
      if (la != lb) return lb.compareTo(la);
      return _byName(a, b);
    case SourceSortOrder.popularReliable:
      // Reliable families first, then by popularity within each group.
      final ua = _isUnreliable(_nameOf(a)) ? 1 : 0;
      final ub = _isUnreliable(_nameOf(b)) ? 1 : 0;
      if (ua != ub) return ua.compareTo(ub);
      return _byPopularity(a, b);
    default:
      return 0;
  }
}

/// [rows] ordered for [order], with pinned sources always first.
///
/// Pinned rows float to the top in every mode, so a source the reader marked as
/// theirs stays where they put it no matter how the rest is ordered. Within the
/// pinned and unpinned groups, [SourceSortOrder.manual] keeps the stored order
/// untouched (the list is already pinned-first and the reader reorders it with
/// "To top"); every other mode sorts with [lastUsed] supplying the recency for
/// [SourceSortOrder.lastUsed].
List<Map<String, dynamic>> sortSourceRows(
  List<Map<String, dynamic>> rows,
  String order, {
  Map<String, int> lastUsed = const {},
}) {
  if (order == SourceSortOrder.manual) {
    return List<Map<String, dynamic>>.from(rows);
  }

  int compare(Map<String, dynamic> a, Map<String, dynamic> b) =>
      _compareRows(a, b, order, lastUsed);

  final pinned = rows.where((r) => r['isPinned'] == true).toList()..sort(compare);
  final rest = rows.where((r) => r['isPinned'] != true).toList()..sort(compare);
  return [...pinned, ...rest];
}
