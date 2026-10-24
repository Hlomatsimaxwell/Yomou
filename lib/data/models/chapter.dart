import 'package:yomou/core/text_sanitizer.dart';

class Chapter {
  final String id;
  final String title;
  final String chapterNumber;
  final String? releaseDate;
  final String url;
  final String scanlator;

  Chapter({
    required this.id,
    required String title,
    required this.chapterNumber,
    this.releaseDate,
    required this.url,
    String scanlator = '',
  })  // The sanitizer rides in through the constructor for the same reason
      // as everywhere else scraped text is cleaned: one gate, not one per
      // source parser.
      : title = title.sanitizeMangaText(),
        scanlator = scanlator.sanitizeMangaText();

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      chapterNumber: json['chapterNumber'] ?? '',
      releaseDate: json['releaseDate'] ?? '',
      url: json['url'] ?? '',
      scanlator: json['scanlator'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'chapterNumber': chapterNumber,
      'releaseDate': releaseDate,
      'url': url,
      'scanlator': scanlator,
    };
  }
}