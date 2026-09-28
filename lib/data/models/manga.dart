class Manga {
  final String id;
  final String title;
  final String coverUrl;
  final String? description;
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
  });

  factory Manga.fromJson(Map<String, dynamic> json) {
    return Manga(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      description: json['description'],
      sourceId: json['sourceId'] ?? '',
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
