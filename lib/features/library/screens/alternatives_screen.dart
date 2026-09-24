import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/data/services/manga_migration.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/library/providers/alternatives_provider.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/safe_image.dart';

enum _AltSort { best, chapters, closest, priority }

typedef _Row = ({AltSource alt, AltMangaHit hit});

const _lavender = Color(0xFF9F7AEA);
const _cardLightBg = Color(0xFFFFFFFF);
const _screenLightBg = Color(0xFFF8F9FA);
const _titleLight = Color(0xFF212121);
const _metaLight = Color(0xFF757575);

/// Kotatsu-style "Alternatives": search the same work across every configured
/// source, compare chapter counts, and migrate progress onto a new source copy.
/// Each source resolves independently so rows appear as each finishes and the
/// source counter ticks up live.
class AlternativesScreen extends ConsumerStatefulWidget {
  final String mangaId;
  final String title;
  final String? imageUrl;
  final String? currentSourceId;
  final String? currentSourceName;
  final String? currentSourceLanguage;
  final int originalTotal;

  const AlternativesScreen({
    super.key,
    required this.mangaId,
    required this.title,
    this.imageUrl,
    this.currentSourceId,
    this.currentSourceName,
    this.currentSourceLanguage,
    this.originalTotal = 0,
  });

  @override
  ConsumerState<AlternativesScreen> createState() => _AlternativesScreenState();
}

class _AlternativesScreenState extends ConsumerState<AlternativesScreen> {
  late final TextEditingController _searchController;
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  String _activeQuery = '';
  bool _searchActive = false;
  _AltSort _sort = _AltSort.best;
  bool _showOnlyEnabled = true;
  bool _sameLanguage = false;
  bool _sameType = false;
  final Set<String> _selectedSources = <String>{};

  @override
  void initState() {
    super.initState();
    _activeQuery = widget.title.isEmpty ? '' : widget.title;
    _searchController = TextEditingController(text: _activeQuery);
    _searchController.addListener(_onTextChanged);
    _searchFocus.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onTextChanged);
    _searchFocus.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _activateSearch() {
    setState(() => _searchActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _activeQuery = '';
      _searchActive = false;
    });
    _searchFocus.unfocus();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      final q = value.trim();
      if (q == _activeQuery) return;
      if (!mounted) return;
      setState(() {
        _activeQuery = q;
        _sort = _AltSort.best;
      });
    });
  }

  List<String> _tokens(String value) =>
      value
          .toLowerCase()
          .split(RegExp(r'[,/]'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

  // The source rows already list a source's declared languages *and* content
  // types (e.g. "Manga, Manhwa, Manhua, English"), so both "same language" and
  // "same content type" are computed over that same field. Empty on either side
  // means "unknown", which never filters.
  bool _sameLanguageFilter(AltSource alt) {
    final cur = _tokens(widget.currentSourceLanguage ?? '');
    final cand = _tokens(alt.language);
    if (cur.isEmpty || cand.isEmpty) return true;
    return cur.any(cand.contains);
  }

  bool _sameTypeFilter(AltSource alt) {
    const types = ['manga', 'manhwa', 'manhua', 'comic', 'novel'];
    final cur = _tokens(widget.currentSourceLanguage ?? '')
        .where((t) => types.contains(t))
        .toList();
    final cand = _tokens(alt.language)
        .where((t) => types.contains(t))
        .toList();
    if (cur.isEmpty || cand.isEmpty) return true;
    return cur.any(cand.contains);
  }

  List<_Row> _filtered(List<_Row> all) {
    var list = all.where((r) {
      if (_showOnlyEnabled && !r.alt.isEnabled) return false;
      if (_selectedSources.isNotEmpty && !_selectedSources.contains(r.alt.id)) {
        return false;
      }
      if (_sameLanguage && !_sameLanguageFilter(r.alt)) return false;
      if (_sameType && !_sameTypeFilter(r.alt)) return false;
      return true;
    }).toList();

    final originalTotal = widget.originalTotal;
    switch (_sort) {
      case _AltSort.best:
        list.sort(
          (a, b) => relevanceScore(a.hit.manga, _activeQuery).compareTo(
            relevanceScore(b.hit.manga, _activeQuery),
          ),
        );
      case _AltSort.chapters:
        list.sort((a, b) {
          final x = a.hit.totalChapters ?? -1;
          final y = b.hit.totalChapters ?? -1;
          return x != y ? y.compareTo(x) : 0;
        });
      case _AltSort.closest:
        list.sort((a, b) {
          final x = a.hit.totalChapters;
          final y = b.hit.totalChapters;
          if (x == null && y == null) return 0;
          if (x == null) return 1;
          if (y == null) return -1;
          return (x - originalTotal).abs().compareTo((y - originalTotal).abs());
        });
      case _AltSort.priority:
        break;
    }
    return list;
  }

  Future<void> _refresh() async {
    final configured = ref.read(configuredAltSourcesProvider);
    final futures = <Future<void>>[];
    for (final s in configured) {
      final provider = sourceAlternativesProvider((
        sourceId: s.id,
        sourceName: s.name,
        query: _activeQuery,
      ));
      SourceCache.invalidatePrefix('${s.id}/list/');
      ref.invalidate(provider);
      futures.add(
        ref.read(provider.future).then((_) {}).catchError((_) {}),
      );
    }
    await Future.wait(futures);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? Theme.of(context).scaffoldBackgroundColor : _screenLightBg;

    final configured = ref.watch(configuredAltSourcesProvider);
    final rows = <_Row>[];
    var stillLoading = 0;
    var withResults = 0;
    for (final s in configured) {
      final v = ref.watch(sourceAlternativesProvider((
        sourceId: s.id,
        sourceName: s.name,
        query: _activeQuery,
      )));
      if (v.isLoading) {
        stillLoading++;
        continue;
      }
      final data = v.valueOrNull;
      if (data != null && data.hasHits) {
        withResults++;
        for (final hit in data.hits) {
          rows.add((alt: s, hit: hit));
        }
      }
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: _searchActive
            ? _buildSearchField(l, dark)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.alternatives,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: dark ? Colors.white : _titleLight,
                    ),
                  ),
                  if (widget.currentSourceName != null)
                    Text(
                      _subtitle(l),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: dark ? Colors.white60 : _metaLight,
                      ),
                    ),
                ],
              ),
        actions: [
          if (!_searchActive)
            IconButton(
              icon: Icon(
                RemixIcons.search_line,
                color: dark ? Colors.white : _titleLight,
              ),
              onPressed: _activateSearch,
            ),
          IconButton(
            icon: Icon(
              RemixIcons.filter_3_line,
              color: dark ? Colors.white : _titleLight,
            ),
            onPressed: () => _showFilterSheet(l),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(l, dark, withResults, configured.length),
          Expanded(
            child: _buildContent(l, dark, rows, stillLoading),
          ),
          if (stillLoading > 0) _FooterSpinner(dark: dark),
        ],
      ),
    );
  }

  String _subtitle(AppLocalizations l) {
    final parts = <String>[
      if (widget.currentSourceName != null && widget.currentSourceName!.isNotEmpty)
        widget.currentSourceName!,
      if (widget.currentSourceLanguage != null && widget.currentSourceLanguage!.isNotEmpty)
        widget.currentSourceLanguage!,
      if (widget.originalTotal > 0) l.chaptersCount(widget.originalTotal),
    ];
    return parts.join(' · ');
  }

  Widget _buildSearchField(AppLocalizations l, bool dark) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            autofocus: true,
            onChanged: _onSearchChanged,
            onSubmitted: (_) {
              _searchFocus.unfocus();
              setState(() => _searchActive = false);
            },
            textInputAction: TextInputAction.search,
            style: TextStyle(
              color: dark ? Colors.white : _titleLight,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: _lavender,
            decoration: InputDecoration(
              hintText: l.searchManga,
              hintStyle: TextStyle(
                color: dark ? Colors.white30 : const Color(0xFF9E9E9E),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: Icon(
              RemixIcons.close_line,
              size: 20,
              color: dark ? Colors.white70 : _metaLight,
            ),
            onPressed: _clearSearch,
          ),
      ],
    );
  }

  Widget _buildFilterBar(
    AppLocalizations l,
    bool dark,
    int withResults,
    int totalSources,
  ) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _activateSearch,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F3F4),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: dark ? Colors.white12 : const Color(0xFFE0E0E0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    RemixIcons.search_line,
                    size: 15,
                    color: dark ? Colors.white60 : _metaLight,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? l.searchManga
                          : _searchController.text.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _searchController.text.trim().isEmpty
                            ? (dark ? Colors.white38 : const Color(0xFF9E9E9E))
                            : (dark ? Colors.white : _titleLight),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F3F4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: dark ? Colors.white24 : const Color(0xFFE0E0E0),
                ),
              ),
              child: Text(
                l.altSourcesCount(withResults, totalSources),
                style: TextStyle(
                  color: dark ? Colors.white70 : _metaLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _showOnlyEnabled = !_showOnlyEnabled),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _showOnlyEnabled
                      ? _lavender.withValues(alpha: 0.14)
                      : (dark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F3F4)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _showOnlyEnabled ? _lavender : (dark ? Colors.white24 : const Color(0xFFE0E0E0)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showOnlyEnabled
                          ? RemixIcons.checkbox_circle_fill
                          : RemixIcons.checkbox_circle_line,
                      size: 15,
                      color: _lavender,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      l.altEnabledSources,
                      style: const TextStyle(
                        color: _lavender,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    AppLocalizations l,
    bool dark,
    List<_Row> rows,
    int stillLoading,
  ) {
    final candidates = _filtered(rows);

    if (_activeQuery.trim().isEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints.expand(),
        child: Center(
          child: Text(
            l.searchManga,
            style: TextStyle(color: dark ? Colors.white38 : const Color(0xFF9E9E9E)),
          ),
        ),
      );
    }

    if (candidates.isEmpty && stillLoading == 0) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: EmptyState(
          icon: RemixIcons.global_off_line,
          title: l.noResultsFound,
          subtitle: l.tryDifferentSearch,
        ),
      );
    }

    return RefreshIndicator(
      color: dark ? Colors.white : _metaLight,
      backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) => candidates.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(height: constraints.maxHeight),
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                itemCount: candidates.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) =>
                    _buildItem(l, dark, candidates[index]),
              ),
      ),
    );
  }

  Widget _buildItem(
    AppLocalizations l,
    bool dark,
    _Row row,
  ) {
    final hit = row.hit;
    final total = hit.totalChapters;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF232326) : _cardLightBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? Colors.white12 : const Color(0xFFE0E0E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: hit.manga.coverUrl.isEmpty
                ? const _AltCoverPlaceholder(width: 56, height: 76)
                : SafeNetworkImage(
                    imageUrl: hit.manga.coverUrl,
                    width: 56,
                    height: 76,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) =>
                        const _AltCoverPlaceholder(width: 56, height: 76),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hit.manga.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark ? Colors.white : _titleLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                if (total != null)
                  _ChapterCountRow(
                    total: total,
                    original: widget.originalTotal,
                    dark: dark,
                  ),
                const SizedBox(height: 10),
                _SourcePill(alt: row.alt, dark: dark),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ReplaceButton(dark: dark, onTap: () => _showMigrationDialog(l, row)),
        ],
      ),
    );
  }

  void _showMigrationDialog(AppLocalizations l, _Row row) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark ? Colors.white : _titleLight;
    final primary = const Color(0xFF7C4DFF);

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(RemixIcons.swap_box_line, color: primary, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              l.altMigrateTitle,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l.altMigrateBody(
                widget.title,
                widget.currentSourceName ?? '',
                row.hit.manga.title,
                row.alt.name,
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: dark ? Colors.white60 : _metaLight,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.altMigrate,
              style: TextStyle(color: primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) _migrate(row, l);
    });
  }

  Future<void> _migrate(_Row row, AppLocalizations l) async {
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: _lavender,
        ),
      ),
    );

    try {
      await migrateManga(
        oldMangaId: widget.mangaId,
        newMangaId: row.hit.manga.id,
        newSourceId: row.alt.id,
        newTitle: row.hit.manga.title,
        newCoverUrl: row.hit.manga.coverUrl,
        newSourceName: row.alt.name,
      );
    } catch (_) {
      if (mounted) {
        nav.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.altMigrateFailed)),
        );
      }
      return;
    }

    if (!mounted) return;
    nav.pop();
    bumpHistoryRevision(ref);
    bumpFavoritesRevision(ref);
    bumpDownloadsRevision(ref);

    if (!mounted) return;
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) => MangaDetailScreen(
          mangaId: row.hit.manga.id,
          title: row.hit.manga.title,
          imageUrl: row.hit.manga.coverUrl,
          sourceId: row.alt.id,
        ),
      ),
    );
  }

  void _showFilterSheet(AppLocalizations l) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: dark ? const Color(0xFF2E2E33) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        var showSources = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final rows = ref
                .read(sourcesProvider)
                .where((r) =>
                    (r['name']?.toString() ?? '') != 'Mock Source')
                .toList();
            final textColor = dark ? Colors.white : _titleLight;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: dark ? Colors.white38 : const Color(0xFFBDBDBD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Row(
                      children: [
                        if (showSources)
                          IconButton(
                            icon: Icon(
                              RemixIcons.arrow_left_line,
                              color: textColor,
                            ),
                            onPressed: () => setSheet(() => showSources = false),
                          ),
                        Expanded(
                          child: Text(
                            showSources ? l.altSources : l.altSortTitle,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(l.done, style: TextStyle(color: textColor)),
                        ),
                      ],
                    ),
                  ),
                  if (showSources)
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          CheckboxListTile(
                            value: _selectedSources.isEmpty,
                            onChanged: (v) => setSheet(
                              () => _selectedSources.clear(),
                            ),
                            title: Text(
                              l.altAllSources,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            activeColor: _lavender,
                            dense: true,
                          ),
                          for (final row in rows)
                            CheckboxListTile(
                              value: _selectedSources.contains(
                                getSourceByName(row['name'] as String).id,
                              ),
                              onChanged: (v) {
                                final id = getSourceByName(
                                  row['name'] as String,
                                ).id;
                                setSheet(() {
                                  if (v == true) {
                                    _selectedSources.add(id);
                                  } else {
                                    _selectedSources.remove(id);
                                  }
                                });
                              },
                              title: Text(
                                row['name'] as String,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                row['language'] as String? ?? '',
                                style: TextStyle(
                                  color: dark
                                      ? Colors.white38
                                      : const Color(0xFF9E9E9E),
                                  fontSize: 12,
                                ),
                              ),
                              activeColor: _lavender,
                              dense: true,
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSortRow(
                              ctx,
                              _AltSort.best,
                              l.altSortBest,
                              dark,
                            ),
                            _buildSortRow(
                              ctx,
                              _AltSort.chapters,
                              l.altSortMostChapters,
                              dark,
                            ),
                            _buildSortRow(
                              ctx,
                              _AltSort.closest,
                              l.altSortClosest,
                              dark,
                            ),
                            _buildSortRow(
                              ctx,
                              _AltSort.priority,
                              l.altSortPriority,
                              dark,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(
                                RemixIcons.stack_line,
                                color: textColor,
                              ),
                              title: Text(
                                l.altSources,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: Icon(
                                RemixIcons.arrow_right_s_line,
                                color: dark
                                    ? Colors.white60
                                    : const Color(0xFF9E9E9E),
                              ),
                              onTap: () => setSheet(() => showSources = true),
                            ),
                            CheckboxListTile(
                              value: _sameLanguage,
                              onChanged: (v) =>
                                  setSheet(() => _sameLanguage = v ?? false),
                              title: Text(
                                l.altSameLanguage,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                ),
                              ),
                              activeColor: _lavender,
                              dense: true,
                            ),
                            CheckboxListTile(
                              value: _sameType,
                              onChanged: (v) =>
                                  setSheet(() => _sameType = v ?? false),
                              title: Text(
                                l.altSameType,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                ),
                              ),
                              activeColor: _lavender,
                              dense: true,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortRow(
    BuildContext ctx,
    _AltSort value,
    String label,
    bool dark,
  ) {
    final selected = _sort == value;
    final primary = const Color(0xFF7C4DFF);
    return ListTile(
      dense: true,
      leading: Icon(
        selected ? RemixIcons.checkbox_circle_fill : RemixIcons.radio_button_line,
        color: selected ? primary : (dark ? Colors.white38 : const Color(0xFF9E9E9E)),
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: dark ? Colors.white : _titleLight,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: () {
        setState(() => _sort = value);
        Navigator.pop(ctx);
      },
    );
  }
}

class _ChapterCountRow extends StatelessWidget {
  final int total;
  final int original;
  final bool dark;

  const _ChapterCountRow({
    required this.total,
    required this.original,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final delta = original > 0 ? total - original : 0;
    final Widget marker;
    if (delta > 0) {
      marker = Text(
        '▲ +$delta',
        style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.w700),
      );
    } else if (delta < 0) {
      marker = Text(
        '▼ $delta',
        style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 12, fontWeight: FontWeight.w700),
      );
    } else {
      marker = Text(
        '—',
        style: TextStyle(color: dark ? Colors.white38 : const Color(0xFFBDBDBD), fontSize: 12),
      );
    }
    return Row(
      children: [
        Text(
          AppLocalizations.of(context).chaptersCount(total),
          style: TextStyle(
            color: dark ? Colors.white60 : const Color(0xFF757575),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        marker,
      ],
    );
  }
}

class _SourcePill extends StatelessWidget {
  final AltSource alt;
  final bool dark;

  const _SourcePill({required this.alt, required this.dark});

  @override
  Widget build(BuildContext context) {
    final iconUrl = alt.source.iconUrl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconUrl.isNotEmpty
              ? ClipOval(
                  child: SafeNetworkImage(
                    imageUrl: iconUrl,
                    width: 14,
                    height: 14,
                    fit: BoxFit.cover,
                  ),
                )
              : CircleAvatar(
                  radius: 7,
                  backgroundColor: dark ? Colors.white24 : Colors.black12,
                  child: Text(
                    alt.name.characters.first,
                    style: TextStyle(
                      color: dark ? Colors.white : Colors.black54,
                      fontSize: 8,
                    ),
                  ),
                ),
          if (iconUrl.isNotEmpty) const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${alt.name} (${alt.language.isNotEmpty ? alt.language : '?'})',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dark ? Colors.white60 : const Color(0xFF757575),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AltCoverPlaceholder extends StatelessWidget {
  final double width;
  final double height;

  const _AltCoverPlaceholder({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(color: Color(0xFFE0E0E0)),
      child: const Icon(
        RemixIcons.book_line,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

class _ReplaceButton extends StatelessWidget {
  final bool dark;
  final VoidCallback onTap;

  const _ReplaceButton({required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white70 : const Color(0xFF616161);
    final border = dark ? Colors.white24 : const Color(0xFFBDBDBD);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(RemixIcons.swap_box_line, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                AppLocalizations.of(context).altReplace,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterSpinner extends StatelessWidget {
  final bool dark;

  const _FooterSpinner({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 18),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: _lavender,
            backgroundColor: dark
                ? Colors.white.withValues(alpha: 0.15)
                : const Color(0xFFE0E0E0),
          ),
        ),
      ),
    );
  }
}