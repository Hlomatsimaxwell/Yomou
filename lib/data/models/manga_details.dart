import 'package:yomou/core/text_sanitizer.dart';

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

  /// Canonical website URL of this manga, when the source's own API reports
  /// one (e.g. Asura Scans' `public_url`, which carries the site's volatile
  /// slug hash and therefore can only come from the API, not be guessed).
  /// Empty when unknown; "Open in browser" then falls back to the source's
  /// [MangaSource.websiteMangaUrl].
  final String publicUrl;

  // Not const, deliberately: scraped strings run through [sanitizeMangaText]
  // here, at the gate every detail parser passes through. Nothing in the
  // codebase needs this in a constant context, and a `const` field of text
  // the source mangled would be worse than the redesign.
  MangaDetails({
    required this.id,
    required String title,
    required this.coverUrl,
    required this.sourceId,
    String description = '',
    String author = '',
    this.status = '',
    this.year = '',
    List<String> tags = const [],
    this.followers = 0,
    this.totalChapters = 0,
    this.language = '',
    this.translations = const [],
    this.publicUrl = '',
  })  : title = title.sanitizeMangaText(),
        description = description.sanitizeMangaText(),
        author = author.sanitizeMangaText(),
        tags = List<String>.unmodifiable(
          tags.map((tag) => tag.sanitizeMangaText()),
        );

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
      publicUrl: json['publicUrl'] ?? '',
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
      'publicUrl': publicUrl,
    };
  }
}
