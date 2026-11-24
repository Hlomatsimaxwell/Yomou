import 'dart:convert';

/// One collection listed in a GigaViewer source's filter sheet.
///
/// [ids] are the raw GraphQL node ids from the upstream multisrc subclasses:
/// a bare decimal string is a `SerialGroup`, a `Genre:<digits>` string is a
/// genre. [GigaViewerSiteConfig.nodeId] turns either into the base64 `ID!`
/// the GraphQL API expects. An empty list means the collection is rendered by
/// the website but left out of the API (Sunday Web Every's 夜サンデー).
class GigaViewerFilterOption {
  const GigaViewerFilterOption({required this.label, required this.ids});

  final String label;
  final List<String> ids;

  factory GigaViewerFilterOption.fromJson(Map<String, dynamic> json) {
    return GigaViewerFilterOption(
      label: json['label'] as String? ?? '',
      ids: (json['ids'] as List?)?.map((e) => '$e').toList() ?? const <String>[],
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'ids': ids,
  };
}

/// Configuration for one GigaViewer-themed site (Japanese Next.js / GraphQL
/// comic viewer, e.g. Comic Action, Shonen Jump+, MAGCOMI).
///
/// Every bundled site of this theme runs the same application with a different
/// domain and artwork, so one [GigaViewerSource] serves them all. The only
/// site-specific knowledge lives in the generated catalog: the serial-group
/// ids that make up its catalogue, its filter options, and a couple of
/// collection modes for sites whose front page is rendered by HTML instead of
/// GraphQL.
class GigaViewerSiteConfig {
  const GigaViewerSiteConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.language = 'Manga, Japanese',
    this.langCode = 'ja',
    this.iconUrl = '',
    this.isNsfw = false,
    this.seriesListIds = const <String>[],
    this.filterOptions = const <GigaViewerFilterOption>[],
    this.catalogMode = 'graphql',
    this.latestMode = 'graphql',
    this.nightCollectionPath = '',
    this.unavailableWhenStatusNull = false,
  });

  /// Source id, also stored as `sourceId` on manga rows.
  final String id;

  /// Display name shown in the source list.
  final String name;

  /// Site origin, e.g. `https://comic-action.com`.
  final String baseUrl;

  /// Human-readable language shown on the source tile.
  final String language;

  /// ISO language code used for localized metadata.
  final String langCode;

  /// Logo shown on the source tile.
  final String iconUrl;

  /// Whether the catalog marks this site as adult-only.
  final bool isNsfw;

  /// Serial groups that form the site's default catalogue.
  final List<String> seriesListIds;

  /// Collections offered by the filter sheet, in display order.
  final List<GigaViewerFilterOption> filterOptions;

  /// 'graphql' (default), 'comicborder' or 'shonenjumpplus'.
  final String catalogMode;

  /// 'graphql' (default) or 'shonenjumpplus' (weekday schedule).
  final String latestMode;

  /// Path to a collection the API leaves out of its lists (夜サンデー).
  final String nightCollectionPath;

  /// Zenon reports closed chapters as readable; only a missing `status`
  /// gives them away.
  final bool unavailableWhenStatusNull;

  /// GraphQL endpoint relative to the effective (possibly overridden) base.
  String get apiPath => '/graphql';

  /// Encodes a raw group/genre id as the base64 `ID!` used by `node(id:)`.
  /// Ids that already carry a type prefix are left in that form.
  static String nodeId(String raw) {
    final value = raw.contains(':') ? raw : 'SerialGroup:$raw';
    return base64.encode(utf8.encode(value));
  }

  DateTime? parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  factory GigaViewerSiteConfig.fromJson(Map<String, dynamic> json) {
    return GigaViewerSiteConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      language: json['language'] as String? ?? 'Manga, Japanese',
      langCode: json['langCode'] as String? ?? 'ja',
      iconUrl: json['iconUrl'] as String? ?? '',
      isNsfw: json['nsfw'] as bool? ?? false,
      seriesListIds: (json['seriesListIds'] as List?)
          ?.map((e) => '$e')
          .toList() ??
          const <String>[],
      filterOptions: (json['filterOptions'] as List?)
          ?.map(
            (e) => GigaViewerFilterOption.fromJson(
              (e as Map).cast<String, dynamic>(),
            ),
          )
          .toList() ??
          const <GigaViewerFilterOption>[],
      catalogMode: json['catalogMode'] as String? ?? 'graphql',
      latestMode: json['latestMode'] as String? ?? 'graphql',
      nightCollectionPath: json['nightCollectionPath'] as String? ?? '',
      unavailableWhenStatusNull:
          json['unavailableWhenStatusNull'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'language': language,
      'langCode': langCode,
      'iconUrl': iconUrl,
      'nsfw': isNsfw,
      'seriesListIds': seriesListIds,
      'filterOptions': filterOptions.map((o) => o.toJson()).toList(),
      'catalogMode': catalogMode,
      'latestMode': latestMode,
      'nightCollectionPath': nightCollectionPath,
      'unavailableWhenStatusNull': unavailableWhenStatusNull,
    };
  }
}
