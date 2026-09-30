import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/theme/colors.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
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

    // Rows appear in the same order as the reference list, and the blank
    // dividers between its groups are kept as plain separators: only E-Ink
    // carries a name there, so inventing titles for the rest would be a guess.
    return Scaffold(
      appBar: SettingsAppBar(title: l.settingsReader),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // --- 1. READING ---
          _PickerRow(
            icon: RemixIcons.book_2_line,
            title: l.rsetDefaultMode,
            subtitle: l.rsetDefaultModeSub,
            value: _modeLabel(l, s.readingMode),
            onTap: () => _pick(
              context: context,
              title: l.rsetDefaultMode,
              options: [
                ('standard', l.rsetModeStandard),
                ('rightToLeft', l.rsetModeRtl),
                ('vertical', l.rsetModeVertical),
                ('webtoon', l.rsetModeWebtoon),
              ],
              selected: s.readingMode,
              onSelect: n.setReadingMode,
            ),
          ),
          _ToggleRow(
            icon: RemixIcons.layout_row_line,
            title: l.rsetTwoPages,
            subtitle: l.rsetTwoPagesSub,
            value: s.twoPages,
            onChanged: n.setTwoPages,
          ),
          const _Gap(),

          // --- 2. SCALE ---
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
          _SliderRow(
            icon: RemixIcons.zoom_out_line,
            title: l.rsetWebtoonZoomOut,
            subtitle: l.rsetWebtoonZoomOutSub,
            value: '${s.webtoonZoomOut}%',
            value_: s.webtoonZoomOut.toDouble(),
            max: 50,
            divisions: 5,
            onChanged: (v) => n.setWebtoonZoomOut(v.round()),
          ),
          _ToggleRow(
            icon: RemixIcons.stack_line,
            title: l.rsetWebtoonGaps,
            subtitle: l.rsetWebtoonGapsSub,
            value: s.webtoonGaps,
            onChanged: n.setWebtoonGaps,
          ),
          const _Gap(),

          // --- 3. CONTROLS ---
          _NavRow(
            icon: RemixIcons.cursor_hand,
            title: l.settingsReaderActions,
            subtitle: l.ractMenuSubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReaderActionsScreen()),
            ),
          ),
          _ToggleRow(
            icon: RemixIcons.volume_up_line,
            title: l.rsetVolumeButtons,
            subtitle: l.rsetVolumeButtonsSub,
            value: s.volumeButtons,
            onChanged: n.setVolumeButtons,
          ),
          _ToggleRow(
            icon: RemixIcons.swap_line,
            title: l.rsetInvertNavigation,
            subtitle: l.rsetInvertNavigationSub,
            value: s.invertNavigation,
            onChanged: n.setInvertNavigation,
          ),
          const _Gap(),

          // --- 4. COLOUR AND MEMORY ---
          // Android's RGB_565 mode has no Flutter equivalent — the engine is
          // always 32-bit — so the row says so rather than showing a switch
          // that cannot do anything.
          _ToggleRow(
            icon: RemixIcons.palette_line,
            title: l.rsetColorMode32,
            subtitle: l.rsetColorMode32Sub,
            value: false,
            enabled: false,
            onChanged: (v) async {},
          ),
          _ToggleRow(
            icon: RemixIcons.cpu_line,
            title: l.rsetReduceMemory,
            subtitle: l.rsetReduceMemorySub,
            value: s.reduceMemory,
            onChanged: n.setReduceMemory,
          ),
          const _Gap(),

          // --- 5. E-INK ---
          // Shown on every device: Android offers no way to ask whether a
          // panel is e-ink, and the flash is off until the user asks for it.
          M3SectionHeader(title: l.rsetSectionEInk),
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
          _PickerRow(
            icon: RemixIcons.drop_line,
            title: l.rsetFlashWith,
            value: _flashLabel(l, s.flashWith),
            enabled: s.flashOnPageChange,
            onTap: () => _pick(
              context: context,
              title: l.rsetFlashWith,
              options: [
                (kFlashWhite, l.rsetFlashWhite),
                (kFlashBlack, l.rsetFlashBlack),
              ],
              selected: s.flashWith,
              onSelect: n.setFlashWith,
            ),
          ),
          const _Gap(),

          // --- 6. SCREEN ---
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
          const _Gap(),

          // --- 7. INFORMATION BAR ---
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
          const _Gap(),

          // --- 8. CANVAS ---
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

          // Last, so it reads as a footnote on everything above it rather than
          // as the first thing a user has to decode.
          _Note(l.rsetDefaultsNote),
        ],
      ),
    );
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

  static String _flashLabel(AppLocalizations l, String id) {
    return id == kFlashBlack ? l.rsetFlashBlack : l.rsetFlashWhite;
  }
}

/// Row that opens another screen: a label block and a chevron, with no value of
/// its own, so it is not mistaken for a picker.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: _RowLabel(icon: icon, title: title, subtitle: subtitle),
      trailing: Icon(
        RemixIcons.arrow_right_s_line,
        color: Theme.of(context).colorScheme.outline,
      ),
      onTap: onTap,
    );
  }
}

/// Separator between the reference list's groups. A hairline rather than a gap,
/// so a run of disabled rows still reads as one block.
class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

/// Muted explanation of what the screen actually changes.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(RemixIcons.information_line, size: 18, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.35, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared title/subtitle block, so a row's label block keeps the same rhythm
/// whether the row is a picker, a toggle or a slider.
class _RowLabel extends StatelessWidget {
  const _RowLabel({
    required this.icon,
    required this.title,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Disabled rows drop to half opacity with a mid-grey title, which reads as
    // inactive without inventing a colour that isn't in the theme.
    final titleColor = enabled ? cs.onSurface : cs.onSurfaceVariant;
    final subColor = enabled ? cs.onSurfaceVariant : cs.outline;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 1),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Icon(icon, size: 26, color: titleColor),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12.5, height: 1.3, color: subColor),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Picker row: leading icon, label block, current value, chevron. Flat — no
/// card, no elevation, the list itself is the surface.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String value;
  final Future<void> Function() onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: ListTile(
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: _RowLabel(
          icon: icon,
          title: title,
          subtitle: subtitle,
          enabled: enabled,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4, left: 38),
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: enabled ? cs.primary : cs.onSurfaceVariant),
          ),
        ),
        trailing: Icon(RemixIcons.arrow_right_s_line, color: cs.outline),
        onTap: onTap,
      ),
    );
  }
}

/// Toggle row. The switch uses the live accent so it matches whichever colour
/// scheme the user picked rather than always the default blue.
class _ToggleRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentProvider);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SwitchListTile(
        value: value,
        onChanged: enabled ? (v) => onChanged(v) : null,
        activeThumbColor: Colors.white,
        activeTrackColor: accent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: _RowLabel(
          icon: icon,
          title: title,
          subtitle: subtitle,
          enabled: enabled,
        ),
      ),
    );
  }
}

/// Slider row: label and live value on one line, the slider beneath it. On a
/// dark surface the unfilled track is the tinted accent surface rather than a
/// default grey, so the whole control stays in the app's palette.
class _SliderRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentProvider);

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _RowLabel(
                    icon: icon,
                    title: title,
                    subtitle: subtitle,
                    enabled: enabled,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: enabled ? accent : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: enabled ? accent : cs.outline,
                thumbColor: enabled ? accent : cs.outline,
                overlayColor: accent.withValues(alpha: 0.12),
                inactiveTrackColor: dark ? kAccentSurface : cs.surfaceContainerHighest,
                trackHeight: 3,
              ),
              child: Slider(
                value: value_.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: enabled ? (v) => onChanged(v) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
