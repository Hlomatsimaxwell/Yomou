class Manga {
  final String id;
  final String title;
  final String coverUrl;
  final String? description;

  /// The id of the source this title was listed by.
  ///
  /// Checked on construction because this field was silently wrong in eight
  /// listing parsers at once, and the damage stayed invisible until much later:
  /// the resolver looked the value up, found nothing, and every affected title
  /// reported itself as coming from a source that was never installed. Each of
  /// those parsers had declared a local `id` holding the manga's own path,
  /// which shadowed the source's `id` getter, so `sourceId: id` wrote the
  /// slug instead of the source. A slug is never a valid source id, so the
  /// check rejects the whole class rather than these eight instances of it.
  final String sourceId;

  /// Genre/tag labels, when the source supplies them on its listing rows.
  ///
  /// Empty for most sources, which is fine: it only matters where a listing
  /// would otherwise have to be re-fetched one row at a time just to learn its
  /// tags. See the related-titles ranking in the detail screen.
  final List<String> tags;

  Manga({
    required this.id,
    required this.title,
    required this.coverUrl,
    this.description,
    required this.sourceId,
    this.tags = const [],
  }) {
    if (!looksLikeSourceId(sourceId)) {
      throw ArgumentError.value(
        sourceId,
        'sourceId',
        'not a source id. A listing parser passed its own slug -- '
            'pass the source instead: sourceId: this.id',
      );
    }
  }

  factory Manga.fromJson(Map<String, dynamic> json) {
    final rawSource = json['sourceId'];
    return Manga(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      description: json['description'],
      // Rows written by the parsers that got this wrong carry a slug here, and
      // rows written before this field existed carry nothing. A slug is dropped
      // rather than passed on, so such a title reports itself as having no
      // known source instead of naming one that cannot exist. An empty value is
      // kept: that is the honest answer for a source that supplied no id.
      sourceId: looksLikeSourceId(rawSource) ? rawSource : '',
      // Rows cached before this field existed have no `tags` key, and the
      // suggestions engine has already stored some rows with null in it.
      tags: (json['tags'] as List?)?.map((t) => '$t').toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverUrl': coverUrl,
      'description': description,
      'sourceId': sourceId,
      'tags': tags,
    };
  }
}

/// Whether [value] can be a source id rather than a manga's own address.
///
/// Source ids are bare tokens: `mangadex-es`, `mangafire-ptbr`. The parsers
/// that got this wrong wrote a slug or a path instead -- `manga/1861/slug`,
/// `https://manhwa18.com/manga/slug` -- and a slug is always distinguishable
/// from an id by carrying a `/`, which no id in this app does.
///
/// Deliberately not a lookup in the resolver's table: this runs inside `Manga`'s
/// constructor, and the resolver imports every source, which imports this. The
/// check stays a rule about the shape of a value rather than a dependency on
/// the list of sources that happen to exist today.
bool looksLikeSourceId(Object? value) {
  if (value is! String) return false;
  if (value.isEmpty) return true;
  return !value.contains('/') && !value.contains('\\');
}
