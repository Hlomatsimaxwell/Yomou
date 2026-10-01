import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/settings/providers/reader_settings_provider.dart';
import 'package:yomou/features/settings/screens/reader_actions_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// Settings > Reader: the global defaults a chapter starts from.
///
/// A title that already carries its own stored choice keeps it, so these are
/// defaults rather than overrides — the note at the top says so, because a
/// switch that visibly does nothing for one title would otherwise look broken.
class ReaderSettingsScreen extends ConsumerWidget {
  const ReaderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(readerSettingsProvider);
    final n = ref.read(readerSettingsProvider.notifier);

    // Which reading mode is the default decides what the rest of the screen
    // can honestly claim. The reader runs one of two builders: a horizontal
    // pager, or a vertical strip. Two pages only exists on the pager; the strip
    // settings only exist on the strip. Rows that the active mode cannot honour
    // are disabled and say why, rather than taking a tap and doing nothing.
    final paged = modeIsPaged(s.readingMode);
    final strip = modeIsVertical(s.readingMode);

    return Scaffold(
      appBar: SettingsAppBar(title: l.settingsReader),
      // Flat list with section headers, the same shape every other settings
      // screen uses. The rows were once grouped into raised cards; the cards
      // were the only thing on this screen that no other settings screen had,
      // and they read as panels inside a panel once the detail pane itself is
      // already a distinct surface.
      body: CappedContentWidth(child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          M3SectionHeader(title: l.rsetSectionReading),
          _PickerRow(
            icon: RemixIcons.book_2_line,
            title: l.rsetDefaultMode,
            subtitle: l.rsetDefaultModeSub,
            value: _modeLabel(l, s.readingMode),
            onTap: () => _pick(
              context: context,
              title: l.rsetDefaultMode,
              options: [
                (kModeStandard, l.rsetModeStandard),
                (kModeRtl, l.rsetModeRtl),
                (kModeVertical, l.rsetModeVertical),
                (kModeWebtoon, l.rsetModeWebtoon),
              ],
              selected: s.readingMode,
              onSelect: n.setReadingMode,
            ),
          ),
          _ToggleRow(
            icon: RemixIcons.layout_row_line,
            title: l.rsetTwoPages,
            subtitle: paged ? l.rsetTwoPagesSub : l.rsetTwoPagesUnavailable,
            value: s.twoPages,
            enabled: paged,
            onChanged: n.setTwoPages,
          ),
          _PickerRow(
            icon: RemixIcons.aspect_ratio_line,
            title: l.rsetScaleMode,
            subtitle: l.rsetScaleModeSub,
            value: _scaleLabel(l, s.scaleMode),
            onTap: () => _pick(
              context: context,
              title: l.rsetScaleMode,
              options: [
                (kScaleFitCenter, l.rsetScaleFitCenter),
                (kScaleFitHeight, l.rsetScaleFitHeight),
                (kScaleFitWidth, l.rsetScaleFitWidth),
                (kScaleKeepAtStart, l.rsetScaleKeepAtStart),
              ],
              selected: s.scaleMode,
              onSelect: n.setScaleMode,
            ),
          ),

          // Its own section rather than trailing the scale picker: both rows
          // here are read inside the reader's vertical builder, so they belong
          // with the reading mode that selects it, not with how a page is fitted
          // to the screen.
          M3SectionHeader(title: l.rsetSectionStrip),
          _SliderRow(
            icon: RemixIcons.zoom_out_line,
            title: l.rsetWebtoonZoomOut,
            subtitle: strip
                ? l.rsetWebtoonZoomOutSub
                : l.rsetStripUnavailable,
            value: '${s.webtoonZoomOut}%',
            value_: s.webtoonZoomOut.toDouble(),
            max: 50,
            divisions: 5,
            enabled: strip,
            onChanged: (v) => n.setWebtoonZoomOut(v.round()),
          ),
          _ToggleRow(
            icon: RemixIcons.stack_line,
            title: l.rsetWebtoonGaps,
            subtitle: strip ? l.rsetWebtoonGapsSub : l.rsetStripUnavailable,
            value: s.webtoonGaps,
            enabled: strip,
            onChanged: n.setWebtoonGaps,
          ),

          M3SectionHeader(title: l.rsetSectionControls),
          _NavRow(
            icon: RemixIcons.cursor_hand,
            title: l.settingsReaderActions,
            subtitle: l.ractMenuSubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReaderActionsScreen()),
            ),
          ),
          // Volume keys are the one setting the platform can refuse. Android
          // intercepts the press outright; iOS has no equivalent, so the port
          // has to observe and undo, which can fail. When it does the row is
          // disabled and says why rather than offering a switch that does
          // nothing.
          Builder(
            builder: (context) {
              final available =
                  ref.watch(readerVolumeKeysAvailableProvider).value ?? true;
              return _ToggleRow(
                icon: RemixIcons.volume_up_line,
                title: l.rsetVolumeButtons,
                subtitle: available
                    ? l.rsetVolumeButtonsSub
                    : l.rsetVolumeButtonsUnavailable,
                value: s.volumeButtons,
                enabled: available,
                onChanged: n.setVolumeButtons,
              );
            },
          ),
          _ToggleRow(
            icon: RemixIcons.swap_line,
            title: l.rsetInvertNavigation,
            subtitle: l.rsetInvertNavigationSub,
            value: s.invertNavigation,
            onChanged: n.setInvertNavigation,
          ),
          _ToggleRow(
            icon: RemixIcons.cpu_line,
            title: l.rsetReduceMemory,
            subtitle: l.rsetReduceMemorySub,
            value: s.reduceMemory,
            onChanged: n.setReduceMemory,
          ),

          M3SectionHeader(title: l.rsetSectionEInk),
          // Shown on every device: Android offers no way to ask whether a
          // panel is e-ink, and the flash is off until the user asks for it.
          _ToggleRow(
            icon: RemixIcons.flashlight_line,
            title: l.rsetFlashOnChange,
            subtitle: l.rsetFlashOnChangeSub,
            value: s.flashOnPageChange,
            onChanged: n.setFlashOnPageChange,
          ),
          _SliderRow(
            icon: RemixIcons.timer_line,
            title: l.rsetFlashDuration,
            subtitle: l.rsetFlashDurationSub,
            value: '${s.flashDurationMs} ms',
            value_: s.flashDurationMs.toDouble(),
            min: 100,
            max: 1000,
            divisions: 18,
            enabled: s.flashOnPageChange,
            onChanged: (v) => n.setFlashDuration(v.round()),
          ),
          _SliderRow(
            icon: RemixIcons.repeat_2_line,
            title: l.rsetFlashEvery,
            subtitle: l.rsetFlashEverySub,
            value: l.rsetFlashEveryUnit(s.flashEvery),
            value_: s.flashEvery.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            enabled: s.flashOnPageChange,
            onChanged: (v) => n.setFlashEvery(v.round()),
          ),
          // Two values, so both are on screen at once rather than behind a
          // sheet that has to be opened, read, and dismissed to change a
          // single bit.
          _SegmentedRow(
            icon: RemixIcons.drop_line,
            title: l.rsetFlashWith,
            subtitle: l.rsetFlashWithSub,
            value: s.flashWith,
            enabled: s.flashOnPageChange,
            options: [
              (kFlashWhite, l.rsetFlashWhite),
              (kFlashBlack, l.rsetFlashBlack),
            ],
            onSelect: n.setFlashWith,
          ),

          M3SectionHeader(title: l.rsetSectionDisplay),
          _ToggleRow(
            icon: RemixIcons.fullscreen_line,
            title: l.rsetFullscreen,
            subtitle: l.rsetFullscreenSub,
            value: s.fullscreen,
            onChanged: n.setFullscreen,
          ),
          _PickerRow(
            icon: RemixIcons.smartphone_line,
            title: l.rsetOrientation,
            subtitle: l.rsetOrientationSub,
            value: _orientationLabel(l, s.orientation),
            onTap: () => _pick(
              context: context,
              title: l.rsetOrientation,
              options: [
                (kOrientDefault, l.rsetOrientDefault),
                (kOrientAutomatic, l.rsetOrientAutomatic),
                (kOrientPortrait, l.rsetOrientPortrait),
                (kOrientLandscape, l.rsetOrientLandscape),
              ],
              selected: s.orientation,
              onSelect: n.setOrientation,
            ),
          ),
          _ToggleRow(
            icon: RemixIcons.sun_line,
            title: l.rsetKeepScreenOn,
            subtitle: l.rsetKeepScreenOnSub,
            value: s.keepScreenOn,
            onChanged: n.setKeepScreenOn,
          ),
          _ToggleRow(
            icon: RemixIcons.information_line,
            title: l.rsetShowInfoBar,
            subtitle: l.rsetShowInfoBarSub,
            value: s.showInfoBar,
            onChanged: n.setShowInfoBar,
          ),
          // Only meaningful while the bar is on, so it dims rather than hides.
          _ToggleRow(
            icon: RemixIcons.image_line,
            title: l.rsetTransparentInfoBar,
            subtitle: l.rsetTransparentInfoBarSub,
            value: s.transparentInfoBar,
            enabled: s.showInfoBar,
            onChanged: n.setTransparentInfoBar,
          ),
          _ToggleRow(
            icon: RemixIcons.message_2_line,
            title: l.rsetShowChapterPopup,
            subtitle: l.rsetShowChapterPopupSub,
            value: s.showChapterPopup,
            onChanged: n.setShowChapterPopup,
          ),

          M3SectionHeader(title: l.rsetSectionPages),
          _PickerRow(
            icon: RemixIcons.paint_line,
            title: l.rsetBackground,
            subtitle: l.rsetBackgroundSub,
            value: _backgroundLabel(l, s.background),
            onTap: () => _pick(
              context: context,
              title: l.rsetBackground,
              options: [
                (kBgDefault, l.rsetBgDefault),
                (kBgLight, l.rsetBgLight),
                (kBgDark, l.rsetBgDark),
                (kBgWhite, l.rsetBgWhite),
                (kBgBlack, l.rsetBgBlack),
              ],
              selected: s.background,
              onSelect: n.setBackground,
            ),
          ),
          _ToggleRow(
            icon: RemixIcons.hashtag,
            title: l.rsetNumberedPages,
            subtitle: l.rsetNumberedPagesSub,
            value: s.numberedPages,
            onChanged: n.setNumberedPages,
          ),
          _PickerRow(
            icon: RemixIcons.download_2_line,
            title: l.rsetPreload,
            subtitle: l.rsetPreloadSub,
            value: _preloadLabel(l, s.preload),
            onTap: () => _pick(
              context: context,
              title: l.rsetPreload,
              options: [
                (kPreloadAlways, l.rsetPreloadAlways),
                (kPreloadWifiOnly, l.rsetPreloadWifiOnly),
                (kPreloadNever, l.rsetPreloadNever),
              ],
              selected: s.preload,
              onSelect: n.setPreload,
            ),
          ),

          _NavRow(
            icon: RemixIcons.refresh_line,
            title: l.rsetReset,
            subtitle: l.rsetResetSub,
            destructive: true,
            onTap: () => _confirmReset(context, ref),
          ),

          // A statement about the whole screen rather than a caption for the
          // rows above it, so it sits below them all and carries no section.
          SettingsFootnote(l.rsetDefaultsNote),

          const SizedBox(height: 24),
        ],
      )),
    );
  }

  /// Reset asks first: it is the one row on the screen that throws away work
  /// rather than storing it, and there is nothing in the reader to undo it.
  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.rsetResetTitle),
        content: Text(l.rsetResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l.reset,
              // The destructive colour, not the accent: the button's whole job
              // is to say this one is not like the others.
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(readerSettingsProvider.notifier).resetToDefaults();
  }

  /// Option sheet shared by every picker row: a row per option with an accent
  /// check on the current one, and a Cancel footer.
  static Future<void> _pick({
    required BuildContext context,
    required String title,
    required List<(String, String)> options,
    required String selected,
    required Future<void> Function(String) onSelect,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final picked = await showM3ModalSheet<String>(
      context,
      title: title,
      children: [
        for (final (id, label) in options)
          ListTile(
            title: Text(label),
            trailing: id == selected
                ? Icon(RemixIcons.check_line, color: cs.primary)
                : null,
            onTap: () => Navigator.pop(context, id),
          ),
      ],
      footer: Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel, style: TextStyle(color: cs.primary)),
        ),
      ),
    );
    if (picked == null) return;
    await onSelect(picked);
  }

  static String _orientationLabel(AppLocalizations l, String id) {
    switch (id) {
      case kOrientAutomatic:
        return l.rsetOrientAutomatic;
      case kOrientPortrait:
        return l.rsetOrientPortrait;
      case kOrientLandscape:
        return l.rsetOrientLandscape;
      default:
        return l.rsetOrientDefault;
    }
  }

  static String _modeLabel(AppLocalizations l, String id) {
    switch (id) {
      case 'standard':
        return l.rsetModeStandard;
      case 'rightToLeft':
        return l.rsetModeRtl;
      case 'webtoon':
        return l.rsetModeWebtoon;
      default:
        return l.rsetModeVertical;
    }
  }

  static String _scaleLabel(AppLocalizations l, String id) {
    switch (id) {
      case kScaleFitHeight:
        return l.rsetScaleFitHeight;
      case kScaleFitWidth:
        return l.rsetScaleFitWidth;
      case kScaleKeepAtStart:
        return l.rsetScaleKeepAtStart;
      default:
        return l.rsetScaleFitCenter;
    }
  }

  static String _backgroundLabel(AppLocalizations l, String id) {
    switch (id) {
      case kBgLight:
        return l.rsetBgLight;
      case kBgDark:
        return l.rsetBgDark;
      case kBgWhite:
        return l.rsetBgWhite;
      case kBgBlack:
        return l.rsetBgBlack;
      default:
        return l.rsetBgDefault;
    }
  }

  static String _preloadLabel(AppLocalizations l, String id) {
    switch (id) {
      case kPreloadWifiOnly:
        return l.rsetPreloadWifiOnly;
      case kPreloadNever:
        return l.rsetPreloadNever;
      default:
        return l.rsetPreloadAlways;
    }
  }

}

/// Row that opens another screen: label, description and a chevron, with no
/// value of its own, so it is not mistaken for a picker.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// Tints the label and the chevron with the error colour, for the one row
  /// that discards rather than stores, so it does not read as another
  /// destination.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: destructive ? cs.error : null),
      title: Text(
        title,
        style: destructive ? TextStyle(color: cs.error) : null,
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(
        RemixIcons.arrow_right_s_line,
        color: destructive ? cs.error : cs.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

/// Picker row: the current value trails the label, then a chevron.
///
/// The shape the other settings screens already use for a row that opens a
/// sheet, so a value-bearing row here does not have its own layout.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String value;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(width: 4),
          Icon(RemixIcons.arrow_right_s_line, color: cs.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Toggle row.
///
/// A row the active reading mode cannot honour is switched off by passing a
/// null callback, which is also how the switch gets the standard disabled
/// treatment: no separate dimming to keep in step with the framework's.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final Future<void> Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: enabled ? (v) => onChanged(v) : null,
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
    );
  }
}

/// Slider row: label and live value on one line, the slider beneath it.
///
/// The icon and label sit on the same grid as a [ListTile]'s leading and title,
/// so the two row kinds line up down the screen without the block needing a
/// card to hold it together. The slider itself is the plain themed one, as
/// every other settings screen's slider is.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.value_,
    required this.onChanged,
    this.subtitle,
    this.min = 0,
    this.max = 100,
    this.divisions,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String value;
  final double value_;
  final double min;
  final double max;
  final int? divisions;
  final bool enabled;
  final Future<void> Function(double) onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Same muted tones the theme uses for disabled text, so a row that cannot
    // act looks the same here as it does in the switch rows above.
    final titleColor = enabled ? cs.onSurface : cs.onSurfaceVariant;
    final subColor = enabled ? cs.onSurfaceVariant : cs.outline;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Icon(
                  icon,
                  size: 24,
                  color: enabled ? cs.onSurfaceVariant : cs.outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: titleColor)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: subColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  value,
                  style: TextStyle(
                    color: enabled ? cs.onSurfaceVariant : cs.outline,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value_.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? (v) => onChanged(v) : null,
          ),
        ],
      ),
    );
  }
}

/// Two-option control shown inline instead of behind a sheet.
///
/// For a pair of mutually exclusive values a sheet is the wrong shape: it hides
/// the choice behind a navigation step, and the user has to remember what the
/// other option was called. Both are visible here at once, and picking one is a
/// single tap.
class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onSelect,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String value;
  final List<(String, String)> options;
  final Future<void> Function(String) onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subColor = enabled ? cs.onSurfaceVariant : cs.outline;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Icon(
                  icon,
                  size: 24,
                  color: enabled ? cs.onSurfaceVariant : cs.outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: TextStyle(fontSize: 12, color: subColor),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Aligned to the label column rather than the row's, so the control
          // belongs to the text it belongs to.
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  for (final (id, label) in options)
                    Expanded(
                      child: _Segment(
                        label: label,
                        selected: id == value,
                        enabled: enabled,
                        onTap: () => onSelect(id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        height: 30,
        decoration: BoxDecoration(
          // The selected segment is a raised chip on the track, the way a
          // segmented control reads. An accent fill would fight the switch
          // rows above it for attention.
          color: selected ? cs.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: enabled
                ? (selected ? cs.onSurface : cs.onSurfaceVariant)
                : cs.outline,
          ),
        ),
      ),
    );
  }
}

/// Muted note at the foot of the screen.
///
/// Screen-level, not a section caption: the note it carries ("these are
/// defaults") is a statement about every setting here, so it sits below them
/// all rather than heading any of them.
class SettingsFootnote extends StatelessWidget {
  const SettingsFootnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, height: 1.35, color: cs.onSurfaceVariant),
      ),
    );
  }
}
