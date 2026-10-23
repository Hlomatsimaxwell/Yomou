import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';

import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:yomou/core/widgets/ios/ios_nav_bar.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/features/library/data/custom_cover_store.dart';
import 'package:yomou/features/library/screens/covers_from_sources_screen.dart';

/// Lets the user override a manga's locally stored title and cover artwork.
/// Customizations are kept in the local `manga` row (with the original values
/// snapshotted) so untitling/restoring works, and survive future reads from
/// the source. Pops with `true` when changes were saved.
class EditMangaScreen extends ConsumerStatefulWidget {
  const EditMangaScreen({
    super.key,
    required this.mangaId,
    this.title = '',
    this.imageUrl = '',
    this.sourceId,
  });

  final String mangaId;
  final String title;
  final String imageUrl;
  final String? sourceId;

  @override
  ConsumerState<EditMangaScreen> createState() => _EditMangaScreenState();
}

class _EditMangaScreenState extends ConsumerState<EditMangaScreen> {
  Map<String, dynamic>? _row;
  late final TextEditingController _titleController;

  String _originalTitle = '';
  String _originalCover = '';
  String _effectiveCover = '';

  bool _resetTitle = false;
  bool _resetCover = false;
  bool _saving = false;

  /// The one failure this screen can show inline: a picked cover that could
  /// not be stored. The reference reports its save errors under the tip in
  /// the same spot, rather than raising a transient toast.
  String? _error;

  String get _dbTitle => (_row?['title'] as String?)?.isNotEmpty == true
      ? _row!['title'] as String
      : widget.title;

  String get _dbCover => (_row?['coverUrl'] as String?)?.isNotEmpty == true
      ? _row!['coverUrl'] as String
      : widget.imageUrl;

  String? get _sourceId => (_row?['sourceId'] as String?) ?? widget.sourceId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final row = await DatabaseHelper.instance.getManga(widget.mangaId);
    if (!mounted) return;

    final originalTitle = (row?['originalTitle'] as String?)?.isNotEmpty == true
        ? row!['originalTitle'] as String
        : (row?['title'] as String?) ?? widget.title;
    final originalCover =
        (row?['originalCoverUrl'] as String?)?.isNotEmpty == true
        ? row!['originalCoverUrl'] as String
        : (row?['coverUrl'] as String?) ?? widget.imageUrl;

    setState(() {
      _row = row;
      _originalTitle = originalTitle;
      _originalCover = originalCover;
      _effectiveCover = (row?['coverUrl'] as String?)?.isNotEmpty == true
          ? row!['coverUrl'] as String
          : widget.imageUrl;
      _titleController.text = (row?['title'] as String?)?.isNotEmpty == true
          ? row!['title'] as String
          : widget.title;
    });
  }

  bool get _titleChanged =>
      _titleController.text.trim() != _dbTitle && !_resetTitle;

  bool get _coverChanged => _effectiveCover != _dbCover && !_resetCover;

  Future<void> _save() async {
    if (_saving) return;

    // Ensure a local row exists when the manga was never stored yet.
    Map<String, dynamic>? row = _row;
    if (row == null) {
      await DatabaseHelper.instance.upsertManga(
        mangaId: widget.mangaId,
        title: _originalTitle,
        coverUrl: _originalCover,
        sourceId: _sourceId,
      );
      row = await DatabaseHelper.instance.getManga(widget.mangaId);
      if (!mounted) return;
      setState(() => _row = row);
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final newTitleText = _titleController.text.trim();
    await DatabaseHelper.instance.saveMangaMetadata(
      mangaId: widget.mangaId,
      newTitle: (_titleChanged && newTitleText.isNotEmpty)
          ? newTitleText
          : null,
      newCoverUrl: _coverChanged ? _effectiveCover : null,
      resetTitle: _resetTitle,
      resetCover: _resetCover,
    );

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pickImage() async {
    setState(() => _error = null);
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {}
    if (picked == null || !mounted) return;

    final localUrl = await CustomCoverStore.savePickedCover(
      mangaId: widget.mangaId,
      sourcePath: picked.path,
    );
    if (!mounted) return;

    if (localUrl == null) {
      setState(() {
        _error = AppLocalizations.of(context).editCoverSaveFailed;
      });
      return;
    }

    setState(() {
      _effectiveCover = localUrl;
      _resetCover = false;
    });
  }

  void _useDefaultCover() {
    setState(() {
      _effectiveCover = _originalCover;
      _resetCover = true;
      _error = null;
    });
  }

  Future<void> _showAltCovers() async {
    setState(() => _error = null);
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CoversFromSourcesScreen(
          mangaId: widget.mangaId,
          title: _dbTitle,
          currentCover: _effectiveCover,
        ),
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    setState(() {
      _effectiveCover = selected;
      _resetCover = false;
    });
  }

  void _resetTitleToOriginal() {
    setState(() {
      _titleController.text = _originalTitle;
      _resetTitle = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
    final muted = dark ? Colors.white54 : Colors.black54;

    return PopScope(
      // No discard guard: the reference closes its edit screen throwing
      // unsaved edits away the moment it is dismissed, and its close arrow
      // never asks. The screen only stays put while a save is in flight.
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            IosNavBar(
              showBack: false,
              // Flat like the reference's toolbar: the nav row belongs to
              // the screen, not to a band above it.
              flat: true,
              leading: Center(
                child: AppPress(
                  onTap: () => Navigator.maybePop(context),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(MdiIcons.close, size: 22, color: fg),
                  ),
                ),
              ),
              titleWidget: Text(
                l.mangaEdit,
                style: TextStyle(
                  color: fg,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  // A filled pill, the shape the reference's `button_done`
                  // takes from its theme -- and always live as that button
                  // is: saving an unmodified entry is a round trip the user
                  // can afford, and a greyed pill was reading as a control
                  // painted onto a band.
                  AppPress(
                    onTap: _save,
                    child: Container(
                      // No `alignment` on this box: an aligned Container
                      // grows to fill the nav row's height, which stretched
                      // the pill taller than the reference's 40dp button.
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l.save,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(context, l.editMangaCover),
                    const SizedBox(height: 12),
                    _buildCoverSection(context),
                    const SizedBox(height: 28),
                    _buildSectionTitle(context, l.editMangaTitle),
                    const SizedBox(height: 12),
                    _buildTitleField(context),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          MdiIcons.informationOutline,
                          size: 16,
                          color: muted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.editChangesNote,
                            style: TextStyle(
                              color: muted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: scheme.error, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String label) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
    return Text(
      label,
      style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildCoverSection(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isCustom = _effectiveCover != _originalCover;

    // The reference sizes its edit cover as 30% of the pane with a 13:18
    // plate ratio: proportions that scale with the window instead of a fixed
    // 110px box, which is what kept the cover believable on a tablet pane.
    return LayoutBuilder(
      builder: (context, pane) {
        final coverWidth = pane.maxWidth * 0.3;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: coverWidth,
              height: coverWidth * 18 / 13,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _effectiveCover.isEmpty
                    ? Icon(
                        MdiIcons.bookOpenVariant,
                        color: Colors.white38,
                        size: 28,
                      )
                    : CachedMangaImage(
                        imageUrl: _effectiveCover,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildActionTile(
                    context,
                    icon: MdiIcons.imagePlusOutline,
                    label: l.editPickFromFiles,
                    onTap: _pickImage,
                  ),
                  const SizedBox(height: 4),
                  _buildActionTile(
                    context,
                    icon: MdiIcons.imageMultipleOutline,
                    label: l.editCoversFromSources,
                    onTap: _showAltCovers,
                  ),
                  const SizedBox(height: 4),
                  // The reference greys this row out while there is no custom
                  // cover to fall back from -- an always-live row pointed at
                  // nothing is a control that lies.
                  _buildActionTile(
                    context,
                    icon: MdiIcons.arrowULeftTop,
                    label: l.editUseDefaultCover,
                    onTap: _useDefaultCover,
                    enabled: isCustom,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
    final fgAt = enabled ? fg : fg.withValues(alpha: 0.38);

    // A bare text row, not a card: the reference's `ListItemTextView` sits
    // straight on the screen, icon leading and nothing trailing, with only
    // the row's own rounded ripple to answer a press.
    return AppPress(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(icon, color: fgAt, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: fgAt, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
    final scheme = Theme.of(context).colorScheme;

    final showReset =
        _titleController.text.trim() != _originalTitle || _resetTitle;

    // Outlined like the reference's field, and while it sits empty the
    // original title shows through as a grey hint -- the placeholderText
    // that field fills with the manga's real name, so an emptied field
    // still answers what it used to be. The trailing arrow restores the
    // original rather than wiping to blank: a stronger reset than the
    // reference's clear icon gives.
    return TextField(
      controller: _titleController,
      onChanged: (_) => setState(() {
        _resetTitle = false;
      }),
      textInputAction: TextInputAction.done,
      style: TextStyle(color: fg, fontSize: 15),
      decoration: InputDecoration(
        hintText: _titleController.text.isEmpty
            ? _originalTitle
            : AppLocalizations.of(context).editTitleHint,
        hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: dark ? Colors.white38 : Colors.black38,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        suffixIcon: showReset
            ? AppPress(
                onTap: _resetTitleToOriginal,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : scheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    MdiIcons.arrowULeftTop,
                    size: 18,
                    color: scheme.primary,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
