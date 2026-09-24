import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

/// Horizontal shelf of the most recently read manga shown on the Explore tab
/// above the Sources section. Honors the "Recent shortcuts" toggle; NSFW
/// filtering is derived from the stored manga tags/title when "Hide NSFW from
/// shortcuts" is on.
class RecentMangaShelf extends ConsumerWidget {
  const RecentMangaShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceSettingsProvider);
    if (!appearance.showRecentShortcuts) return const SizedBox.shrink();

    final history = ref.watch(historyProvider).value ?? const [];
    if (history.isEmpty) return const SizedBox.shrink();

    final hideNsfw = appearance.hideNsfwFromShortcuts;
    final seen = <String>{};
    final recents = <Map<String, dynamic>>[];
    for (final item in history) {
      final id = item['mangaId'] as String? ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      if (hideNsfw && _isNsfwItem(item)) continue;
      recents.add(item);
      if (recents.length >= 10) break;
    }
    if (recents.isEmpty) return const SizedBox.shrink();

    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l.homeRecent,
            style: TextStyle(
              color: dark ? Colors.white : const Color(0xFF1C1B1F),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 168,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recents.length,
            itemBuilder: (context, index) {
              return _RecentShortcut(item: recents[index]);
            },
          ),
        ),
      ],
    );
  }

  bool _isNsfwItem(Map<String, dynamic> item) {
    final terms = [
      'hentai',
      'adult',
      'smut',
      'porn',
      'nsfw',
      'erotica',
      'erotic',
      'mature',
      'explicit',
      'x-rated',
    ];
    final words = <String>[item['title']?.toString() ?? ''];
    final rawTags = item['tags'];
    if (rawTags is String && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          words.addAll(decoded.map((t) => t.toString()));
        }
      } catch (_) {}
    }
    final joined = words.join(' ').toLowerCase();
    return terms.any(joined.contains);
  }
}

class _RecentShortcut extends ConsumerWidget {
  const _RecentShortcut({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MangaDetailScreen(
              mangaId: item['mangaId'],
              title: item['title'],
              imageUrl: item['coverUrl'],
              sourceId: item['sourceId'],
            ),
          ),
        );
        if (context.mounted) bumpHistoryRevision(ref);
      },
      child: Container(
        width: 84,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 84,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: dark ? null : Border.all(color: Colors.black12),
                ),
                child: CachedMangaImage(
                  imageUrl: item['coverUrl'],
                  width: 84,
                  height: 120,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    color: dark ? const Color(0xFF2C2C2E) : Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(
                      RemixIcons.book_open_line,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item['title']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}