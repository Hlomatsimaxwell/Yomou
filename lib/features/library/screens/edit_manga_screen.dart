import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:remixicon/remixicon.dart';

import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:yomou/core/widgets/ios/ios_nav_bar.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
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

    setState(() => _saving = true);
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
      showIosToast(
        context,
        message: AppLocalizations.of(context).editCoverSaveFailed,
        duration: const Duration(seconds: 2),
      );
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
    });
  }

  Future<void> _showAltCovers() async {
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
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              IosNavBar(
                showBack: false,
                leading: Center(
                  child: AppPress(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(RemixIcons.close_line, size: 22, color: fg),
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
                    AppPress(
                      onTap: _save,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Text(
                          l.save,
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 17,
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
                            RemixIcons.information_line,
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
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isCustom = _effectiveCover != _originalCover;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 110,
          height: 165,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: dark ? null : Border.all(color: Colors.black12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _effectiveCover.isEmpty
                ? Container(
                    color: const Color(0xFF2C2C2E),
                    child: const Icon(
                      RemixIcons.book_open_line,
                      color: Colors.white38,
                      size: 28,
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedMangaImage(
                        imageUrl: _effectiveCover,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      if (isCustom)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l.editCustomCover,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              _buildActionTile(
                context,
                icon: RemixIcons.image_add_line,
                label: l.editPickFromFiles,
                onTap: _pickImage,
              ),
              const SizedBox(height: 10),
              _buildActionTile(
                context,
                icon: RemixIcons.image_2_line,
                label: l.editCoversFromSources,
                onTap: _showAltCovers,
              ),
              const SizedBox(height: 10),
              _buildActionTile(
                context,
                icon: RemixIcons.arrow_go_back_line,
                label: l.editUseDefaultCover,
                onTap: _useDefaultCover,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);

    return AppPress(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              RemixIcons.arrow_right_s_line,
              color: dark ? Colors.white38 : Colors.black38,
              size: 18,
            ),
          ],
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

    return TextField(
      controller: _titleController,
      onChanged: (_) => setState(() {
        _resetTitle = false;
      }),
      textInputAction: TextInputAction.done,
      style: TextStyle(color: fg, fontSize: 15),
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context).editTitleHint,
        hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
        filled: true,
        fillColor: dark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F3F5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
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
                    RemixIcons.arrow_go_back_line,
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
