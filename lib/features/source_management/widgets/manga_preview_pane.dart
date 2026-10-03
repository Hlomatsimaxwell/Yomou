import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/core/diagnostics/diag_log.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_details.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

/// A quick look at one manga, shown beside a browse grid on a wide layout.
///
/// This is deliberately not a second detail screen. The full screen has a
/// chapter tray, related titles, translation switching, downloads and
/// multi-select; none of that belongs in a pane the width of a phone, and
/// duplicating it here would leave two screens to keep in step. What this
/// carries is the part a browse decision actually needs -- cover, title,
/// author, publication state and summary -- plus the two ways out: read it, or
/// break out to the real screen.
///
/// Author, state, year and summary are only on [MangaDetails], not on the
/// listing rows, so showing them costs one request per newly-tapped cover.
/// It goes through [SourceCache.mangaDetails], the same cache the detail
/// screen reads, so a cover that is previewed and then opened costs nothing
/// extra, and re-tapping it is free.
class MangaPreviewPane extends ConsumerStatefulWidget {
  final Manga manga;

  /// Read it now: open the full detail screen, which fetches the chapters
  /// and starts the reader itself.
  final VoidCallback onRead;

  /// Break out to the full detail screen without starting the reader.
  final VoidCallback onOpenFull;

  final VoidCallback onClose;

  const MangaPreviewPane({
    super.key,
    required this.manga,
    required this.onRead,
    required this.onOpenFull,
    required this.onClose,
  });

  @override
  ConsumerState<MangaPreviewPane> createState() => _MangaPreviewPaneState();
}

class _MangaPreviewPaneState extends ConsumerState<MangaPreviewPane> {
  MangaDetails? _details;
  bool _loading = true;
  String? _error;

  /// Which manga the in-flight request was for.
  ///
  /// Tapping quickly through a grid starts a request per cover, and they do
  /// not come back in order. Without this the pane would render whichever
  /// answer happened to land last, which can be a cover the user has already
  /// tapped past. Comparing against the current manga discards the strays.
  String? _loadingFor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MangaPreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manga.id == widget.manga.id) return;
    setState(() {
      _details = null;
      _error = null;
      _loading = true;
      _loadingFor = null;
    });
    _load();
  }

  Future<void> _load() async {
    final manga = widget.manga;
    _loadingFor = manga.id;
    final source = getSourceBySourceId(manga.sourceId);
    if (source == null) {
      if (!mounted || _loadingFor != manga.id) return;
      diagSoon(
        'preview: no source for mangaId=${manga.id} '
        'sourceId="${manga.sourceId}"',
      );
      setState(() {
        _loading = false;
        _error = _kUnknownSource;
      });
      return;
    }
    try {
      final details = await SourceCache.mangaDetails(
        sourceId: source.id,
        mangaId: manga.id,
        fetch: () => source.getMangaDetails(manga.id),
      );
      if (!mounted || _loadingFor != manga.id) return;
      setState(() {
        _loading = false;
        _details = details;
      });
    } catch (e) {
      if (!mounted || _loadingFor != manga.id) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    final details = _details;
    // Prefer the fetched cover: sources often report a higher-resolution one
    // on the detail endpoint than on the listing row, and the pane has room
    // to show it.
    final coverUrl = (details?.coverUrl.isNotEmpty ?? false)
        ? details!.coverUrl
        : widget.manga.coverUrl;
    final title = (details?.title.isNotEmpty ?? false)
        ? details!.title
        : widget.manga.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, dark, l),
        Expanded(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(
                    color: dark
                        ? Colors.white70
                        : Theme.of(context).colorScheme.primary,
                  ),
                )
              : _error != null
                  ? _buildError(context, dark, l)
                  : _buildBody(context, dark, l, title, coverUrl),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool dark, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(RemixIcons.close_line, size: 22),
            tooltip: l.close,
            onPressed: widget.onClose,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              l.sourcePreview,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(RemixIcons.fullscreen_line, size: 20),
            tooltip: l.openFullDetails,
            onPressed: widget.onOpenFull,
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, bool dark, AppLocalizations l) {
    // A missing source is a different thing from a failed request and gets its
    // own wording: retrying cannot fix a manga whose source is not installed,
    // so offering the button there would be a control that lies.
    if (_error == _kUnknownSource) {
      return EmptyState(
        icon: RemixIcons.link_unlink,
        title: l.previewSourceMissing,
        subtitle: l.previewSourceMissingSubtitle,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              RemixIcons.error_warning_line,
              size: 32,
              color: dark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(height: 12),
            Text(
              l.failedToLoadManga,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: dark
                    ? Colors.white70
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
              icon: const Icon(RemixIcons.refresh_line),
              label: Text(l.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool dark,
    AppLocalizations l,
    String title,
    String coverUrl,
  ) {
    final accent = ref.watch(accentProvider);
    final details = _details;
    // The listing row's own tags when the fetch has not supplied any, so the
    // pane is not bare while loading or on a source that reports none.
    final tags = (details?.tags.isNotEmpty ?? false)
        ? details!.tags
        : widget.manga.tags;
    final description = details?.description.trim() ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: CachedMangaImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: dark ? const Color(0xFF2C2C2E) : Colors.black12,
                  alignment: Alignment.center,
                  child: Icon(
                    RemixIcons.book_open_line,
                    color: dark ? Colors.white38 : Colors.black38,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: dark ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        _metaRow(
          context,
          dark,
          l.detailAuthor,
          (details?.author.isEmpty ?? true) ? l.unknown : details!.author,
        ),
        if ((details?.status.isEmpty ?? true) == false)
          _metaRow(context, dark, l.detailState, details!.status),
        if ((details?.year.isEmpty ?? true) == false)
          _metaRow(context, dark, l.detailYear, details!.year),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFE8EAF0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      color: dark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(
          l.description,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: dark
                ? Colors.white70
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description.isEmpty ? l.noDescription : description,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: dark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
        // Filled with the app's accent rather than outlined. It is the pane's
        // one primary action, and the accent is the same colour the reader's
        // own controls use, so the button is recognisably "go read this" and
        // not just another bordered control sharing the column.
        GestureDetector(
          onTap: widget.onRead,
          child: Container(
            height: 46,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(23),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  RemixIcons.book_read_line,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  l.readAction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaRow(
    BuildContext context,
    bool dark,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: dark ? Colors.white38 : Colors.black45,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _kUnknownSource = 'unknown_source';
}
