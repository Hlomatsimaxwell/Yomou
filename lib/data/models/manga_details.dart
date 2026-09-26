import 'manga_translation.dart';

class MangaDetails {
  final String id;
  final String title;
  final String coverUrl;
  final String sourceId;
  final String description;
  final String author;
  final String status; // e.g. 'ongoing', 'completed'
  final String year;
  final List<String> tags;
  final int followers;
  final int totalChapters;

  /// Language code of this translation (e.g. `en`, `es`, `pt-br`). Empty when
  /// the source doesn't report one; the UI then falls back to the source's
  /// declared language.
  final String language;

  /// Other translations of the same work, when the source publishes more than
  /// one. Empty for single-language sources.
  final List<MangaTranslation> translations;

  const MangaDetails({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.sourceId,
    this.description = '',
    this.author = '',
    this.status = '',
    this.year = '',
    this.tags = const [],
    this.followers = 0,
    this.totalChapters = 0,
    this.language = '',
    this.translations = const [],
  });

  factory MangaDetails.fromJson(Map<String, dynamic> json) {
    return MangaDetails(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      sourceId: json['sourceId'] ?? '',
      description: json['description'] ?? '',
      author: json['author'] ?? '',
      status: json['status'] ?? '',
      year: json['year'] ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      totalChapters: (json['totalChapters'] as num?)?.toInt() ?? 0,
      language: json['language'] ?? '',
      translations: (json['translations'] as List?)
              ?.map((e) => MangaTranslation.fromJson(
                    (e as Map).cast<String, dynamic>(),
                  ))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverUrl': coverUrl,
      'sourceId': sourceId,
      'description': description,
      'author': author,
      'status': status,
      'year': year,
      'tags': tags,
      'followers': followers,
      'totalChapters': totalChapters,
      'language': language,
      'translations': translations.map((t) => t.toJson()).toList(),
    };
  }
}
