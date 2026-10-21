import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/core/diagnostics/diag_log.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/kotatsu_icon.dart';
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
/// author and summary -- plus the two ways out: read it, or break out to the
/// real screen.
///
/// The shape follows the reference preview: the card's single close control
/// sits at the top-right of the header row beside the cover and title, Read
/// and the break-out share the row directly under it, tags follow as outlined
/// pills, and the summary runs on with no caption over it. State and year are
/// deliberately absent here -- their key-value table is what the header was
/// rebuilt to remove, and the full screen's cards still carry both.
///
/// Author and summary are only on [MangaDetails], not on the listing rows, so
/// showing them costs one request per newly-tapped cover. It goes through
/// [SourceCache.mangaDetails], the same cache the detail screen reads, so a
/// cover that is previewed and then opened costs nothing extra, and re-tapping
/// it is free.
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
    // The second line the reference fills with an alt title. This app has no
    // alt-title field, so the honest local equivalent is the other name the
    // two endpoints disagree on: the listing row's own title, shown once the
    // detail endpoint reports a different one. Matching titles say nothing
    // twice and the line stays hidden, the way the reference hides it.
    final alsoKnownAs =
        widget.manga.title.isNotEmpty && widget.manga.title != title
            ? widget.manga.title
            : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Built before the fetch settles: cover and title are what the grid
        // already showed, so the close control -- the one way out of the pane
        // that never waits on a request -- is on screen in every state the
        // body below can be in.
        _buildHeader(
          context,
          dark,
          l,
          title: title,
          coverUrl: coverUrl,
          alsoKnownAs: alsoKnownAs,
          author: details?.author ?? '',
        ),
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
                  : _buildBody(context, dark, l),
        ),
      ],
    );
  }

  /// Cover and title share the row, with the card's only close control at its
  /// top-right corner.
  ///
  /// The cover is a fixed box rather than this app's grid ratio: the grid
  /// crops tall and narrow for a wall of covers, while this header sits at
  /// 13:18 beside the title, and a box inside the reference's own size range
  /// (roughly 110-130 wide) keeps the title column the room it needs. The
  /// reference gets the same proportion by making its own cover 30% of the
  /// pane; a fixed box says the same thing on a pane whose width now follows
  /// the window.
  Widget _buildHeader(
    BuildContext context,
    bool dark,
    AppLocalizations l, {
    required String title,
    required String coverUrl,
    required String alsoKnownAs,
    required String author,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // 16 at the top, matching the body below it: the cover and title now sit
      // inside a card rather than against the pane's own top edge, and 4 -- the
      // value this carried when the pane was a bare column -- left the header
      // crowding the card's border. The sides and bottom keep their old
      // measures: the body's padding already spaces the rest.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 120,
              height: 172,
              child: CachedMangaImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: dark ? const Color(0xFF2C2C2E) : Colors.black12,
                  alignment: Alignment.center,
                  child: Icon(
                    MdiIcons.bookOpenVariant,
                    color: dark ? Colors.white38 : Colors.black38,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The reference's title block: HeadlineSmall (24) in bold, up
                // to five lines, with 4 between the lines beneath it -- its
                // `textView_title`, `textView_subtitle` and `textView_author`
                // and the margins between them. The pane is wide enough now to
                // let a long title run rather than clipping it at two.
                Text(
                  title,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: dark ? Colors.white : scheme.onSurface,
                  ),
                ),
                if (alsoKnownAs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    alsoKnownAs,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: dark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
                if (author.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(MdiIcons.close, size: 22),
            tooltip: l.close,
            onPressed: widget.onClose,
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
        icon: MdiIcons.linkVariantOff,
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
              MdiIcons.alertCircleOutline,
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
              icon: const Icon(MdiIcons.refresh),
              label: Text(l.retry),
            ),
          ],
        ),
      ),
    );
  }

  /// Read and the break-out share the first row, tags follow as pills, and the
  /// summary runs on directly beneath them.
  Widget _buildBody(BuildContext context, bool dark, AppLocalizations l) {
    final accent = ref.watch(accentProvider);
    final details = _details;
    // The listing row's own tags when the fetch has not supplied any, so the
    // pane is not bare while loading or on a source that reports none.
    final tags = (details?.tags.isNotEmpty ?? false)
        ? details!.tags
        : widget.manga.tags;
    final description = details?.description.trim() ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Row(
          children: [
            Expanded(
              // Filled with the app's accent rather than outlined. It is the
              // pane's one primary action, and the accent is the same colour
              // the reader's own controls use, so the button is recognisably
              // "go read this" and not just another bordered control sharing
              // the column. The label flips to black on a pale accent so a
              // white-accent monochrome scheme does not white out its own text.
              child: FilledButton(
                onPressed: widget.onRead,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: accent.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(l.readAction),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                // The reference's own expand glyph, ported as an asset rather
                // than approximated: its `ic_expand` is a two-arrow vector that
                // no glyph in Material's or MDI's fonts matches.
                icon: KotatsuIcon(
                  'ic_expand',
                  size: 18,
                  color: dark
                      ? Colors.white70
                      : Theme.of(context).colorScheme.onSurface,
                ),
                tooltip: l.openFullDetails,
                onPressed: widget.onOpenFull,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
              ),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      width: 1,
                      color: dark ? Colors.white38 : Colors.black38,
                    ),
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
        const SizedBox(height: 12),
        Text(
          description.isEmpty ? l.noDescription : description,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: dark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  static const _kUnknownSource = 'unknown_source';
}
