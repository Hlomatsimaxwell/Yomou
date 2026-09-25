import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/data/models/manga_filter.dart';

/// Presents the filter as a fullscreen sheet: slides up to cover the whole
/// screen (no rounded corners breaking the look when the list scrolls), with
/// the normal iOS-style push transition.
Future<MangaFilter?> showMangaFilterSheet(
  BuildContext context, {
  required MangaFilter initial,
  required List<String> tags,
  required String presetsKey,
  required void Function(MangaFilter filter) onSave,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<MangaFilter>(
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, _) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: Scaffold(
              backgroundColor: iosSheetBackground(context),
              body: SafeArea(
                child: MangaFilterSheet(
                  initial: initial,
                  tags: tags,
                  presetsKey: presetsKey,
                  onSave: onSave,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// The source-catalog filter sheet. Shows every section from the spec — sort,
/// language, genres, excluded genres, publication state and year range — and
/// hands the bundled [MangaFilter] back to the source grid on "Done".
///
/// [onSave] persists the active filter for this source (called by Save + Done).
/// Named presets are stored under [presetsKey] so saved filters can be
/// recalled, renamed and deleted.
class MangaFilterSheet extends ConsumerStatefulWidget {
  final MangaFilter initial;
  final List<String> tags;
  final String presetsKey;
  final void Function(MangaFilter filter) onSave;

  const MangaFilterSheet({
    super.key,
    required this.initial,
    required this.tags,
    required this.presetsKey,
    required this.onSave,
  });

  @override
  ConsumerState<MangaFilterSheet> createState() => _MangaFilterSheetState();
}

class _MangaFilterSheetState extends ConsumerState<MangaFilterSheet> {
  static const _minYear = 1900;
  static const _maxYear = 2027;

  late String _sort;
  String? _language;
  late Set<String> _genres;
  late Set<String> _excludeGenres;
  late Set<String> _status;
  late int _yearFrom;
  late int _yearTo;
  List<SavedFilter> _presets = [];

  @override
  void initState() {
    super.initState();
    _sort = widget.initial.sort;
    _language = widget.initial.language;
    _genres = widget.initial.genres.toSet();
    _excludeGenres = widget.initial.excludeGenres.toSet();
    _status = widget.initial.status.toSet();
    _yearFrom = widget.initial.yearFrom ?? _minYear;
    _yearTo = widget.initial.yearTo ?? _maxYear;
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(widget.presetsKey);
      if (raw == null) return;
      final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _presets = decoded.map(SavedFilter.fromJson).toList();
      });
    } catch (_) {}
  }

  Future<void> _storePresets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      widget.presetsKey,
      jsonEncode(_presets.map((p) => p.toJson()).toList()),
    );
  }

  MangaFilter get _current => MangaFilter(
        sort: _sort,
        language: _language,
        genres: _genres.toList(),
        excludeGenres: _excludeGenres.toList(),
        status: _status.toList(),
        yearFrom: _yearFrom > _minYear || _yearTo < _maxYear
            ? _yearFrom
            : null,
        yearTo: _yearFrom > _minYear || _yearTo < _maxYear ? _yearTo : null,
      );

  Future<void> _showSavePresetDialog() async {
    final l = AppLocalizations.of(context);
    final name = await _promptForName(
      title: l.filterSavePresetTitle,
      hint: l.filterSavePresetHint,
    );
    if (name == null || name.trim().isEmpty) return;
    final trimmed = name.trim();
    setState(() {
      final existing = _presets.indexWhere((p) => p.name == trimmed);
      if (existing != -1) {
        _presets[existing] = SavedFilter(name: trimmed, filter: _current);
      } else {
        _presets.add(SavedFilter(name: trimmed, filter: _current));
      }
    });
    await _storePresets();
    if (!mounted) return;
    showIosToast(context, message: l.filterSavedPreset(trimmed));
  }

  Future<String?> _promptForName({
    required String title,
    required String hint,
    String? initial,
  }) {
    final controller = TextEditingController(text: initial);
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              dark ? const Color(0xFF2C2C2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(
              color: dark ? Colors.white : const Color(0xFF1C1B1F),
            ),
            cursorColor:
                dark ? Colors.white : const Color(0xFF1C1B1F),
            onSubmitted: (_) =>
                Navigator.pop(dialogContext, controller.text.trim()),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: dark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                l.filterCancel,
                style: TextStyle(
                  color: dark ? Colors.white70 : const Color(0xFF49454F),
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(
                l.filterSave,
                style: TextStyle(
                  color: dark
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _applyPreset(SavedFilter preset) {
    setState(() {
      _sort = preset.filter.sort;
      _language = preset.filter.language;
      _genres = preset.filter.genres.toSet();
      _excludeGenres = preset.filter.excludeGenres.toSet();
      _status = preset.filter.status.toSet();
      _yearFrom = preset.filter.yearFrom ?? _minYear;
      _yearTo = preset.filter.yearTo ?? _maxYear;
    });
    showIosToast(
      context,
      message: AppLocalizations.of(context).filterPresetApplied(preset.name),
    );
  }

  Future<void> _showPresetActions(SavedFilter preset) async {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final action = await showIosMenuPanel<String>(
      context,
      children: [
        IosMenuRow(
          icon: RemixIcons.edit_2_line,
          label: l.filterRename,
          onTap: () => Navigator.pop(context, 'rename'),
        ),
        const IosMenuDivider(),
        IosMenuRow(
          icon: RemixIcons.delete_bin_5_line,
          label: l.filterDelete,
          destructive: true,
          onTap: () => Navigator.pop(context, 'delete'),
        ),
      ],
    );
    if (action == null || !mounted) return;
    if (action == 'rename') {
      final newName = await _promptForName(
        title: l.filterRename,
        hint: l.filterSavePresetHint,
        initial: preset.name,
      );
      if (newName == null || newName.trim().isEmpty) return;
      setState(() {
        final index = _presets.indexWhere((p) => p.name == preset.name);
        if (index != -1) {
          _presets[index] =
              SavedFilter(name: newName.trim(), filter: preset.filter);
        }
      });
      await _storePresets();
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor:
              dark ? const Color(0xFF2C2C2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            l.filterDeleteConfirmTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          content: Text(
            l.filterDeleteConfirmBody(preset.name),
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                l.filterCancel,
                style: TextStyle(
                  color: dark ? Colors.white70 : const Color(0xFF49454F),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                l.filterDelete,
                style: const TextStyle(
                  color: Color(0xFFFF453A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() {
        _presets.removeWhere((p) => p.name == preset.name);
      });
      await _storePresets();
      if (!mounted) return;
      showIosToast(context, message: l.filterPresetDeleted);
    }
  }

  void _done() {
    widget.onSave(_current);
    Navigator.pop(context, _current);
  }

  void _reset() {
    setState(() {
      _sort = 'updated';
      _language = null;
      _genres.clear();
      _excludeGenres.clear();
      _status.clear();
      _yearFrom = _minYear;
      _yearTo = _maxYear;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(RemixIcons.close_line, size: 22),
                tooltip: AppLocalizations.of(context).filterClose,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  l.filterTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(RemixIcons.refresh_line, size: 20),
                tooltip: l.filterReset,
                onPressed: _reset,
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel(context, l.filterSort),
                _buildSortPills(dark, scheme),
                if (_presets.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionLabel(context, l.filterSavedFilters),
                  _buildPresetChips(dark, scheme),
                ],
                const SizedBox(height: 24),
                _sectionLabel(context, l.filterLanguage),
                _buildLanguagePills(dark, scheme),
                const SizedBox(height: 24),
                _sectionLabel(context, l.filterGenres),
                _buildWrap(dark, scheme, _genres, (set) {
                  setState(() => _genres = set);
                }),
                const SizedBox(height: 24),
                _sectionLabel(context, l.filterExcludeGenres),
                _buildWrap(dark, scheme, _excludeGenres, (set) {
                  setState(() => _excludeGenres = set);
                }),
                const SizedBox(height: 24),
                _sectionLabel(context, l.filterMangaState),
                _buildStatusPills(dark, scheme),
                const SizedBox(height: 24),
                _sectionLabel(context, l.filterYear),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '$_yearFrom - $_yearTo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : scheme.onSurface,
                    ),
                  ),
                ),
                RangeSlider(
                  values: RangeValues(
                    _yearFrom.toDouble(),
                    _yearTo.toDouble(),
                  ),
                  min: _minYear.toDouble(),
                  max: _maxYear.toDouble(),
                  divisions: _maxYear - _minYear,
                  activeColor: scheme.primary,
                  inactiveColor: dark
                      ? const Color(0xFF2C2C2E)
                      : Colors.black12,
                  labels: RangeLabels('$_yearFrom', '$_yearTo'),
                  onChanged: (values) {
                    setState(() {
                      _yearFrom = values.start.round();
                      _yearTo = values.end.round();
                    });
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: _buildFooterButton(
                  context,
                  label: l.filterSave,
                  filled: false,
                  onTap: _showSavePresetDialog,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFooterButton(
                  context,
                  label: l.filterDone,
                  filled: true,
                  onTap: _done,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Color _unselectedCapsule(bool dark) =>
      dark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EAF0);

  Widget _buildSortPills(bool dark, ColorScheme scheme) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kFilterSorts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (code, label) = kFilterSorts[index];
          final selected = _sort == code;
          return _pill(
            label,
            selected: selected,
            dark: dark,
            scheme: scheme,
            onTap: () => setState(() => _sort = code),
          );
        },
      ),
    );
  }

  Widget _buildLanguagePills(bool dark, ColorScheme scheme) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kFilterLanguages.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final selected = _language == null;
            return _pill(
              AppLocalizations.of(context).filterAllLanguages,
              selected: selected,
              dark: dark,
              scheme: scheme,
              onTap: () => setState(() => _language = null),
            );
          }
          final (code, label) = kFilterLanguages[index - 1];
          final selected = _language == code;
          return _pill(
            label,
            selected: selected,
            dark: dark,
            scheme: scheme,
            onTap: () => setState(() => _language = code),
          );
        },
      ),
    );
  }

  Widget _buildStatusPills(bool dark, ColorScheme scheme) {
    final labels = {
      'finished': AppLocalizations.of(context).filterStateFinished,
      'dropped': AppLocalizations.of(context).filterStateDropped,
      'upcoming': AppLocalizations.of(context).filterStateUpcoming,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in kFilterStatuses)
          _pill(
            labels[status]!,
            selected: _status.contains(status),
            dark: dark,
            scheme: scheme,
            onTap: () => setState(() {
              if (!_status.add(status)) _status.remove(status);
            }),
          ),
      ],
    );
  }

  Widget _buildWrap(
    bool dark,
    ColorScheme scheme,
    Set<String> selected,
    ValueChanged<Set<String>> onChanged,
  ) {
    if (widget.tags.isEmpty) {
      return Text(
        AppLocalizations.of(context).filterNoTags,
        style: TextStyle(
          fontSize: 13,
          color: dark ? Colors.white54 : Colors.black45,
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in widget.tags)
          _capsule(
            tag,
            selected: selected.contains(tag),
            dark: dark,
            scheme: scheme,
            onTap: () {
              final next = Set<String>.from(selected);
              if (!next.add(tag)) next.remove(tag);
              onChanged(next);
            },
          ),
      ],
    );
  }

  Widget _buildPresetChips(bool dark, ColorScheme scheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in _presets)
          _presetChip(preset, dark, scheme),
      ],
    );
  }

  Widget _presetChip(SavedFilter preset, bool dark, ColorScheme scheme) {
    final onSurface = dark ? Colors.white : const Color(0xFF1C1B1F);
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EAF0),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _applyPreset(preset),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 7, 4, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    RemixIcons.bookmark_3_fill,
                    size: 15,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    preset.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showPresetActions(preset),
            child: Padding(
              padding: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
              child: Icon(
                RemixIcons.arrow_down_s_line,
                size: 16,
                color: dark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(
    String label, {
    required bool selected,
    required bool dark,
    required ColorScheme scheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : (dark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EAF0)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? scheme.onPrimary
                : (dark ? Colors.white : const Color(0xFF1C1B1F)),
          ),
        ),
      ),
    );
  }

  Widget _capsule(
    String label, {
    required bool selected,
    required bool dark,
    required ColorScheme scheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : _unselectedCapsule(dark),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? RemixIcons.checkbox_fill
                  : RemixIcons.checkbox_blank_line,
              size: 15,
              color: selected
                  ? scheme.onPrimary
                  : (dark ? Colors.white54 : Colors.black45),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected
                    ? scheme.onPrimary
                    : (dark ? Colors.white : const Color(0xFF1C1B1F)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterButton(
    BuildContext context, {
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? scheme.primary
              : (dark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EAF0)),
          borderRadius: BorderRadius.circular(23),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: filled
                ? scheme.onPrimary
                : (dark ? Colors.white : const Color(0xFF1C1B1F)),
          ),
        ),
      ),
    );
  }
}