import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

/// A single candidate cover, tagged with the source that produced it.
class _CoverOption {
  const _CoverOption({
    required this.url,
    required this.label,
    this.sourceId = '',
    this.isCurrent = false,
  });

  final String url;
  final String label;
  final String sourceId;
  final bool isCurrent;
}

/// Browses cover art for a manga across every active source plugin. Sources
/// are queried concurrently; results stream in as they finish while the header
/// tracks progress. Pops with the chosen cover url, or null when dismissed.
class CoversFromSourcesScreen extends ConsumerStatefulWidget {
  const CoversFromSourcesScreen({
    super.key,
    required this.mangaId,
    required this.title,
    this.currentCover = '',
  });

  final String mangaId;
  final String title;
  final String currentCover;

  @override
  ConsumerState<CoversFromSourcesScreen> createState() =>
      _CoversFromSourcesScreenState();
}

class _CoversFromSourcesScreenState
    extends ConsumerState<CoversFromSourcesScreen> {
  final List<_CoverOption> _options = [];
  final Set<String> _seenUrls = {};
  String? _selectedUrl;
  int _done = 0;
  int _total = 0;

  bool get _isFetching => _done < _total;
  bool get _canApply =>
      _selectedUrl != null && _selectedUrl != widget.currentCover;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<MangaSource> _activeSources() =>
      resolveActiveSources(ref.read(sourcesProvider));

  void _load() {
    if (widget.currentCover.isNotEmpty) {
      _options.add(
        _CoverOption(url: widget.currentCover, label: '', isCurrent: true),
      );
      _seenUrls.add(widget.currentCover);
      _selectedUrl = widget.currentCover;
    }

    final sources = _activeSources();
    setState(() => _total = sources.length);

    for (final source in sources) {
      _fetchForSource(source).then(_onSourceDone);
    }
  }

  Future<List<_CoverOption>> _fetchForSource(MangaSource source) async {
    final found = <_CoverOption>[];

    // Prefer a source's dedicated alternative-cover endpoint (only the origin
    // source understands this manga id; others answer with an empty list).
    try {
      final alts = await source
          .getAltCovers(widget.mangaId)
          .timeout(const Duration(seconds: 10), onTimeout: () => const []);
      for (final alt in alts) {
        if (alt.$1.isEmpty) continue;
        found.add(
          _CoverOption(
            url: alt.$1,
            label: (alt.$2 == null || alt.$2!.isEmpty)
                ? source.name
                : '${source.name} · ${alt.$2}',
            sourceId: source.id,
          ),
        );
      }
    } catch (_) {}

    // Otherwise fall back to a title search so we still surface this source's
    // cover for the same title. Results are validated against the title so a
    // source whose search returns unrelated/junk cards (e.g. it redirects to
    // its homepage) does not contribute bogus covers.
    if (found.isEmpty) {
      try {
        final results = await source
            .searchByTitle(widget.title)
            .timeout(const Duration(seconds: 10), onTimeout: () => const []);
        for (final manga in results) {
          if (manga.coverUrl.isEmpty) continue;
          if (!_titleMatches(manga.title, widget.title)) continue;
          found.add(
            _CoverOption(
              url: manga.coverUrl,
              label: source.name,
              sourceId: source.id,
            ),
          );
          if (found.length >= 3) break;
        }
      } catch (_) {}
    }

    return found;
  }

  String _normalizeTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  bool _titleMatches(String candidate, String target) {
    final c = _normalizeTitle(candidate);
    final t = _normalizeTitle(target);
    if (c.isEmpty || t.isEmpty) return false;
    return c.contains(t) || t.contains(c);
  }

  void _retry() {
    final sources = _activeSources();
    setState(() {
      _options.removeWhere((o) => !o.isCurrent);
      _seenUrls
        ..clear()
        ..addAll(_options.map((o) => o.url));
      _done = 0;
      _total = sources.length;
    });
    for (final source in sources) {
      _fetchForSource(source).then(_onSourceDone);
    }
  }

  void _onSourceDone(List<_CoverOption> found) {
    if (!mounted) return;
    setState(() {
      _done++;
      for (final option in found) {
        if (_seenUrls.add(option.url)) _options.add(option);
      }
    });
  }

  /// MangaDex (and similar CDNs) ship a larger variant of the same cover;
  /// request it for the hero so it renders crisply.
  String _heroUrl(String url) {
    if (url.endsWith('.256.jpg')) {
      return url.replaceAll('.256.jpg', '.512.jpg');
    }
    return url;
  }

  void _apply() {
    final url = _selectedUrl;
    if (url == null) return;
    Navigator.pop(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, l, fg),
            Expanded(child: _buildHero(context, scheme)),
            _buildCarousel(context, l, dark, scheme),
            _buildUseButton(context, l, scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AppLocalizations l, Color fg) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? Colors.white54 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(
              child: AppPress(
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(RemixIcons.close_line, size: 22, color: fg),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.editCoversFromSources,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isFetching) ...[
                      SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      l.coversProgress(_done, _total),
                      style: TextStyle(color: muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, ColorScheme scheme) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = _selectedUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Center(
        child: selected == null
            ? _isFetching
                  ? CircularProgressIndicator(color: scheme.primary)
                  : Icon(
                      RemixIcons.image_2_line,
                      size: 48,
                      color: dark ? Colors.white24 : Colors.black26,
                    )
            : AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedMangaImage(
                    imageUrl: _heroUrl(selected),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCarousel(
    BuildContext context,
    AppLocalizations l,
    bool dark,
    ColorScheme scheme,
  ) {
    if (_options.isEmpty) {
      if (_isFetching) return const SizedBox(height: 150);
      return SizedBox(
        height: 150,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.coversNoResults,
                style: TextStyle(
                  color: dark ? Colors.white54 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              AppPress(
                onTap: _retry,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        RemixIcons.refresh_line,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l.retry,
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final option = _options[index];
          final isSelected = option.url == _selectedUrl;
          final label = option.isCurrent ? l.coversCurrent : option.label;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _selectedUrl = option.url),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 118,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? scheme.primary
                          : (dark ? Colors.white24 : Colors.black12),
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedMangaImage(
                      imageUrl: option.url,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 94,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected
                          ? scheme.primary
                          : (dark ? Colors.white70 : Colors.black87),
                      fontSize: 10.5,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUseButton(
    BuildContext context,
    AppLocalizations l,
    ColorScheme scheme,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = _canApply;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: AppPress(
          onTap: enabled ? _apply : null,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled
                  ? scheme.primary
                  : (dark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              l.coversUseThis,
              style: TextStyle(
                color: enabled
                    ? Colors.white
                    : (dark ? Colors.white38 : Colors.black38),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
