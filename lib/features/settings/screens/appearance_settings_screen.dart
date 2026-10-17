import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:yomou/core/widgets/kotatsu_icon.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/core/security/app_lock.dart';
import 'package:yomou/core/security/pin_lock_screen.dart';
import 'package:yomou/core/theme/amoled.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appearanceSettingsProvider);
    final notifier = ref.read(appearanceSettingsProvider.notifier);
    final l = AppLocalizations.of(context);

    return Scaffold(
      // The pane's own guide is wider than the 16 a settings column defaults
      // to, because the scheme cards below sit on 24 -- their carousel and
      // their own padding make up the difference. Asking for the same margin
      // here keeps the title on that line instead of 8px inside it.
      appBar: SettingsAppBar(title: l.appearanceTitle, contentMargin: 24),
      body: CappedContentWidth(child: SettingsRows(child: ListView(
      // Everything in this pane starts on one guide: 24px from the column's
      // edge, which is this 8 plus the 16 that a ListTile or a section header
      // insets itself by. The carousel below asks for the same 8 for the same
      // reason, so its cards line up with the rows instead of stepping in.
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      children: [
        // Color Scheme Carousel
        M3SectionHeader(title: l.appearanceColorScheme),
        SizedBox(
          // Room for the 116px mini-UI card plus its label.
          height: 148,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            // 12 rather than 8: the list this sits in already contributes 8,
            // and each card adds 4 of its own, which puts the first card's edge
            // on the same 24 as the rows under it. Each card also gives 4 to
            // the gap it shares with its neighbour, so two cards sit 8 apart.
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _SchemePreset(
                name: 'Totoro',
                isActive: settings.colorScheme == 'Totoro',
                onTap: () => notifier.setColorScheme('Totoro'),
              ),
              _SchemePreset(
                name: 'Dynamic',
                isActive: settings.colorScheme == 'Dynamic',
                onTap: () => notifier.setColorScheme('Dynamic'),
              ),
              _SchemePreset(
                name: 'Expressive',
                isActive: settings.colorScheme == 'Expressive',
                onTap: () => notifier.setColorScheme('Expressive'),
              ),
              _SchemePreset(
                name: 'Miku',
                isActive: settings.colorScheme == 'Miku',
                onTap: () => notifier.setColorScheme('Miku'),
              ),
              _SchemePreset(
                name: 'Monochrome',
                isActive: settings.colorScheme == 'Monochrome',
                onTap: () => notifier.setColorScheme('Monochrome'),
              ),
              // The rest of Kotatsu's preset themes, in the order it lists
              // them, so switching between the two apps feels like the same
              // picker.
              _SchemePreset(
                name: 'Asuka',
                isActive: settings.colorScheme == 'Asuka',
                onTap: () => notifier.setColorScheme('Asuka'),
              ),
              _SchemePreset(
                name: 'Mion',
                isActive: settings.colorScheme == 'Mion',
                onTap: () => notifier.setColorScheme('Mion'),
              ),
              _SchemePreset(
                name: 'Rikka',
                isActive: settings.colorScheme == 'Rikka',
                onTap: () => notifier.setColorScheme('Rikka'),
              ),
              _SchemePreset(
                name: 'Sakura',
                isActive: settings.colorScheme == 'Sakura',
                onTap: () => notifier.setColorScheme('Sakura'),
              ),
              _SchemePreset(
                name: 'Mamimi',
                isActive: settings.colorScheme == 'Mamimi',
                onTap: () => notifier.setColorScheme('Mamimi'),
              ),
              _SchemePreset(
                name: 'Kanade',
                isActive: settings.colorScheme == 'Kanade',
                onTap: () => notifier.setColorScheme('Kanade'),
              ),
              _SchemePreset(
                name: 'Itsuka',
                isActive: settings.colorScheme == 'Itsuka',
                onTap: () => notifier.setColorScheme('Itsuka'),
              ),
            ],
          ),
        ),

        // The theme rows sit directly under the picker: the carousel above is
        // already their heading, and a second label over three rows nobody
        // mistakes for anything else was only a line of noise between them.
        ListTile(
          leading: const KotatsuIcon('ic_theme_mode'),
          title: Text(l.appearanceThemeTitle),
          subtitle: Text(_themeModeLabel(l, settings.themeMode)),
          onTap: () => _showThemeModeSelector(context, ref, settings, notifier),
        ),
        // Only meaningful against a dark background, so it is offered only
        // when one is showing: a switch that changes nothing reads as broken.
        if (Theme.of(context).brightness == Brightness.dark)
          SwitchListTile(
            secondary: const KotatsuIcon('ic_dark_mode'),
            title: Text(l.appearanceAmoledBlack),
            subtitle: Text(l.appearanceAmoledBlackSubtitle),
            value: settings.amoledBlack,
            onChanged: (_) => notifier.toggleBool('amoledBlack'),
          ),
        ListTile(
          leading: const KotatsuIcon('ic_language'),
          title: Text(l.appearanceLanguageTitle),
          subtitle: Text(_languageLabel(l, settings.language)),
          onTap: () => _showLanguageSelector(context, ref, settings, notifier),
        ),
        // Frosted glass, reduce motion and haptics are no longer rows. The
        // preferences behind them still exist and the reader, the badges and
        // the carousel still read them -- a device simply keeps whatever value
        // it already stores for each, since nothing here can change it now.

        // Manga List Section
        M3SectionHeader(title: l.appearanceSectionMangaList),
        ListTile(
          leading: const KotatsuIcon('ic_list'),
          title: Text(l.appearanceListModeTitle),
          subtitle: Text(_listModeLabel(l, settings.listMode)),
          onTap: () => _showListModeSelector(context, ref, settings, notifier),
        ),
        ListTile(
          leading: const KotatsuIcon('ic_grid'),
          // Name and value share the label's line, at opposite ends, instead of
          // being spliced into one string: the percent is a reading of the
          // slider under it, not part of the setting's name.
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.appearanceGridSizeTitle,
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                '${settings.gridSize.round()}%',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          subtitle: SizedBox(
            // Material's slider box is 48 high, and it takes that height from
            // its padding: zeroing the padding below would otherwise bring the
            // box down to the thumb's height, so the 48 is stated here instead
            // of being left to follow from a padding this row has changed.
            height: 48,
            child: SliderTheme(
              // Material insets the track by half a thumb at each end so a
              // thumb at either extreme still sits inside it. In this row that
              // stops the track short of the trailing edge -- the edge the
              // value above it ends on and the switches below it sit their
              // thumbs on -- so the track reads as detached from the line it
              // measures. Zero padding paints it across the row's full width.
              data: SliderTheme.of(context).copyWith(padding: EdgeInsets.zero),
              child: Slider(
                value: settings.gridSize,
                min: 50,
                max: 150,
                onChanged: (v) => notifier.setGridSize(v),
              ),
            ),
          ),
        ),
        SwitchListTile(
          secondary: const KotatsuIcon('ic_filter_menu'),
          title: Text(l.appearanceQuickFilters),
          subtitle: Text(l.appearanceQuickFiltersSubtitle),
          value: settings.showQuickFilters,
          onChanged: (_) => notifier.toggleBool('showQuickFilters'),
        ),
        SwitchListTile(
          secondary: const KotatsuIcon('ic_timelapse'),
          title: Text(l.appearanceReadingProgress),
          subtitle: Text(l.appearanceReadingProgressSubtitle),
          value: settings.showReadingProgress,
          onChanged: (_) => notifier.toggleBool('showReadingProgress'),
        ),
        SwitchListTile(
          secondary: const KotatsuIcon('ic_badges'),
          title: Text(l.appearanceBadges),
          subtitle: Text(l.appearanceBadgesSubtitle),
          value: settings.showListBadges,
          onChanged: (_) => notifier.toggleBool('showListBadges'),
        ),

        // Details Section
        M3SectionHeader(title: l.appearanceDetails),
        SwitchListTile(
          secondary: const KotatsuIcon('ic_expand_more'),
          title: Text(l.appearanceCollapseDescription),
          value: settings.collapseDescription,
          onChanged: (_) => notifier.toggleBool('collapseDescription'),
        ),
        SwitchListTile(
          secondary: const KotatsuIcon('ic_images'),
          title: Text(l.appearancePagesThumbnails),
          subtitle: Text(l.appearancePagesThumbnailsSubtitle),
          value: settings.showPagesThumbnails,
          onChanged: (_) => notifier.toggleBool('showPagesThumbnails'),
        ),
        ListTile(
          leading: const KotatsuIcon('ic_list_detailed'),
          title: Text(l.appearanceDefaultTabTitle),
          subtitle: Text(_tabLabel(l, settings.defaultTab)),
          onTap: () => _showDefaultTabSelector(context, ref, settings, notifier),
        ),

        // Main Screen Section
        M3SectionHeader(title: l.appearanceSectionMainScreen),
        ListTile(
          leading: const KotatsuIcon('ic_suggestion'),
          title: Text(l.appearanceSearchSuggestionsTitle),
          subtitle: Text(_suggestionSummary(context, settings)),
          onTap: () => _showSearchSuggestionsSheet(context, ref, settings, notifier),
        ),
        ListTile(
          leading: const KotatsuIcon('ic_drawer_menu'),
          title: Text(l.appearanceMainSectionsTitle),
          subtitle: Text(l.appearanceMainSectionsSubtitle),
          onTap: () => _showMainSectionsSheet(context, ref, settings, notifier),
        ),
        SwitchListTile(
          secondary: const KotatsuIcon('ic_add'),
          title: Text(l.appearanceFloatingContinue),
          value: settings.showFloatingContinueButton,
          onChanged: (_) => notifier.toggleBool('showFloatingContinueButton'),
        ),
        SwitchListTile(
          secondary: const KotatsuIcon('ic_tag'),
          title: Text(l.appearanceNavLabels),
          value: settings.showNavLabels,
          onChanged: (_) => notifier.toggleBool('showNavLabels'),
        ),
        SwitchListTile(
          secondary: const KotatsuIcon('ic_nav_bar'),
          title: Text(l.appearanceFloatingNav),
          value: settings.useFloatingNavBar,
          onChanged: (_) => notifier.toggleBool('useFloatingNavBar'),
        ),
        SwitchListTile(
          secondary: const KotatsuIcon('ic_pin'),
          title: Text(l.appearancePinNav),
          subtitle: Text(l.appearancePinNavSubtitle),
          value: settings.pinNavUiOnScroll,
          onChanged: (_) => notifier.toggleBool('pinNavUiOnScroll'),
        ),
        SwitchListTile(
          secondary: const KotatsuIcon('ic_alert_outline'),
          title: Text(l.appearanceExitConfirmation),
          subtitle: Text(l.appearanceExitConfirmationSubtitle),
          value: settings.exitConfirmation,
          onChanged: (_) => notifier.toggleBool('exitConfirmation'),
        ),
        SwitchListTile(
          secondary: const KotatsuIcon('ic_shortcut'),
          title: Text(l.appearanceRecentShortcuts),
          value: settings.showRecentShortcuts,
          onChanged: (_) => notifier.toggleBool('showRecentShortcuts'),
        ),
        SwitchListTile(
          secondary: const KotatsuIcon('ic_sfw'),
          title: Text(l.appearanceHideNsfwShortcuts),
          value: settings.hideNsfwFromShortcuts,
          onChanged: (_) => notifier.toggleBool('hideNsfwFromShortcuts'),
        ),

        // Privacy Section
        M3SectionHeader(title: l.appearancePrivacy),
        SwitchListTile(
          secondary: const KotatsuIcon('ic_lock'),
          title: Text(l.appearanceProtectApp),
          subtitle: Text(l.appearanceProtectAppSubtitle),
          value: settings.protectApp,
          onChanged: (v) => _handleProtectAppToggle(context, ref, v),
        ),
        ListTile(
          leading: const KotatsuIcon('ic_data_privacy'),
          title: Text(l.appearanceScreenshotPolicyTitle),
          subtitle: Text(settings.screenshotPolicy),
          onTap: () => _showScreenshotPolicySheet(context, ref, settings, notifier),
        ),

        const SizedBox(height: 24),
      ],
    ))),
    );
  }

  void _showThemeModeSelector(
    BuildContext context,
    WidgetRef ref,
    AppearanceSettings settings,
    AppearanceSettingsNotifier notifier,
  ) {
    final l = AppLocalizations.of(context);
    showM3ModalSheet(
      context,
      title: l.appearanceThemeTitle,
      children: [
        _buildThemeOption(
          context,
          l.appearanceThemeSystem,
          ThemeMode.system,
          settings.themeMode,
          notifier,
        ),
        _buildThemeOption(
          context,
          l.appearanceThemeLight,
          ThemeMode.light,
          settings.themeMode,
          notifier,
        ),
        _buildThemeOption(
          context,
          l.appearanceThemeDark,
          ThemeMode.dark,
          settings.themeMode,
          notifier,
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String label,
    ThemeMode mode,
    ThemeMode current,
    AppearanceSettingsNotifier notifier,
  ) {
    return ListTile(
      title: Text(label),
      trailing: mode == current
          ? Icon(MdiIcons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        notifier.setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showLanguageSelector(
    BuildContext context,
    WidgetRef ref,
    AppearanceSettings settings,
    AppearanceSettingsNotifier notifier,
  ) {
    final l = AppLocalizations.of(context);
    final languages = [
      'system', 'en', 'es', 'fr', 'de', 'pt', 'it', 'ru', 'ja', 'ko', 'zh', 'ar', 'hi',
    ];
    final labels = [
      l.languageFollowSystem, l.languageEn, l.languageEs, l.languageFr, l.languageDe,
      l.languagePt, l.languageIt, l.languageRu, l.languageJa, l.languageKo, l.languageZh,
      l.languageAr, l.languageHi,
    ];

    showM3ModalSheet(
      context,
      title: l.appearanceLanguageTitle,
      maxHeightFactor: 0.5,
      children: [
        for (var i = 0; i < languages.length; i++)
          ListTile(
            title: Text(labels[i]),
            trailing: languages[i] == settings.language
                ? Icon(MdiIcons.check, color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () {
              notifier.setLanguage(languages[i]);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  void _showListModeSelector(
    BuildContext context,
    WidgetRef ref,
    AppearanceSettings settings,
    AppearanceSettingsNotifier notifier,
  ) {
    final l = AppLocalizations.of(context);
    showM3ModalSheet(
      context,
      title: l.appearanceListModeTitle,
      children: [
        _buildListModeOption(context, l.listModeGrid, 'Grid', settings.listMode, notifier),
        _buildListModeOption(context, l.listModeList, 'List', settings.listMode, notifier),
      ],
    );
  }

  Widget _buildListModeOption(
    BuildContext context,
    String label,
    String mode,
    String current,
    AppearanceSettingsNotifier notifier,
  ) {
    return ListTile(
      title: Text(label),
      trailing: mode == current
          ? Icon(MdiIcons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        notifier.setListMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showDefaultTabSelector(
    BuildContext context,
    WidgetRef ref,
    AppearanceSettings settings,
    AppearanceSettingsNotifier notifier,
  ) {
    final l = AppLocalizations.of(context);
    final tabs = [
      ('Last used', l.defaultTabLastUsed),
      ('History', l.defaultTabHistory),
      ('Favorites', l.defaultTabFavorites),
      ('Suggestions', l.defaultTabSuggestions),
      ('Explore', l.defaultTabExplore),
      ('Updates', l.defaultTabUpdates),
    ];
    showM3ModalSheet(
      context,
      title: l.appearanceDefaultTabTitle,
      children: [
        for (final tab in tabs)
          ListTile(
            title: Text(tab.$2),
            trailing: tab.$1 == settings.defaultTab
                ? Icon(MdiIcons.check, color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () {
              notifier.setDefaultTab(tab.$1);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  String _themeModeLabel(AppLocalizations l, ThemeMode mode) => switch (mode) {
        ThemeMode.system => l.appearanceThemeSystem,
        ThemeMode.light => l.appearanceThemeLight,
        ThemeMode.dark => l.appearanceThemeDark,
      };

  String _languageLabel(AppLocalizations l, String code) {
    if (code == 'system') return l.languageFollowSystem;
    return switch (code) {
      'en' => l.languageEn,
      'es' => l.languageEs,
      'fr' => l.languageFr,
      'de' => l.languageDe,
      'pt' => l.languagePt,
      'it' => l.languageIt,
      'ru' => l.languageRu,
      'ja' => l.languageJa,
      'ko' => l.languageKo,
      'zh' => l.languageZh,
      'ar' => l.languageAr,
      'hi' => l.languageHi,
      _ => code,
    };
  }

  String _listModeLabel(AppLocalizations l, String mode) =>
      mode == 'Grid' ? l.listModeGrid : l.listModeList;

  String _tabLabel(AppLocalizations l, String tab) => switch (tab) {
        'Last used' => l.defaultTabLastUsed,
        'History' => l.defaultTabHistory,
        'Favorites' => l.defaultTabFavorites,
        'Suggestions' => l.defaultTabSuggestions,
        'Explore' => l.defaultTabExplore,
        'Updates' => l.defaultTabUpdates,
        _ => tab,
      };

  String _suggestionSummary(BuildContext context, AppearanceSettings settings) {
    final l = AppLocalizations.of(context);
    final codeToLabel = {
      'history': l.suggestionHistory,
      'trending': l.suggestionTrending,
      'new': l.suggestionNew,
      'popular': l.suggestionPopular,
    };
    final enabled = settings.searchSuggestions.entries
        .where((e) => e.value)
        .map((e) => codeToLabel[e.key] ?? e.key.capitalize())
        .toList();
    return enabled.isEmpty ? AppLocalizations.of(context).appearanceNone : enabled.join(', ');
  }

  void _showSearchSuggestionsSheet(
    BuildContext context,
    WidgetRef ref,
    AppearanceSettings settings,
    AppearanceSettingsNotifier notifier,
  ) {
    final l = AppLocalizations.of(context);
    const optionKeys = ['history', 'trending', 'new', 'popular'];
    final optionLabels = [
      l.suggestionHistory,
      l.suggestionTrending,
      l.suggestionNew,
      l.suggestionPopular,
    ];
    showM3ModalSheet(
      context,
      title: l.appearanceSearchSuggestionsTitle,
      children: [
        for (var i = 0; i < optionKeys.length; i++)
          SwitchListTile(
            title: Text(optionLabels[i]),
            value: settings.searchSuggestions[optionKeys[i]] ?? true,
            onChanged: (_) => notifier.toggleSearchSuggestion(optionKeys[i]),
          ),
      ],
    );
  }

  void _showMainSectionsSheet(
    BuildContext context,
    WidgetRef ref,
    AppearanceSettings settings,
    AppearanceSettingsNotifier notifier,
  ) {
    final l = AppLocalizations.of(context);
    showM3ModalSheet(
      context,
      title: l.appearanceMainSectionsTitle,
      children: [
        for (final entry in settings.mainScreenSections.entries)
          SwitchListTile(
            title: Text(_tabLabel(l, entry.key)),
            value: entry.value,
            onChanged: (_) => notifier.toggleMainSection(entry.key),
          ),
      ],
    );
  }

  // Protecting the app requires a PIN: setting one on enable, verifying the
  // current one before disabling.
  Future<void> _handleProtectAppToggle(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final controller = ref.read(appLockProvider.notifier);
    final l = AppLocalizations.of(context);

    if (enable) {
      if (!controller.hasPin) {
        final pin = await _promptPin(
          context,
          title: l.appLockSetTitle,
          subtitle: l.appLockSetSubtitle,
          onVerify: (_) => true,
        );
        if (pin == null) return;
        await controller.setPin(pin);
      }
      await ref.read(appearanceSettingsProvider.notifier).setProtectApp(true);
    } else {
      final pin = await _promptPin(
        context,
        title: l.appLockVerifyTitle,
        subtitle: l.appLockVerifySubtitle,
        onVerify: controller.verify,
      );
      if (pin == null) return;
      await ref.read(appearanceSettingsProvider.notifier).setProtectApp(false);
    }
  }

  Future<String?> _promptPin(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool Function(String) onVerify,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? amoled(context, 0xFF1C1C1E)
          : Colors.white,
      isScrollControlled: true,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      builder: (context) {
        final nav = Navigator.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: SingleChildScrollView(
            child: PinEntryView(
              title: title,
              subtitle: subtitle,
              onVerify: onVerify,
              onSuccess: nav.pop,
              onCancel: () => nav.pop(),
            ),
          ),
        );
      },
    );
  }

  void _showScreenshotPolicySheet(
    BuildContext context,
    WidgetRef ref,
    AppearanceSettings settings,
    AppearanceSettingsNotifier notifier,
  ) {
    final l = AppLocalizations.of(context);
    const policyCodes = ['Allow', 'Block'];
    final policyLabels = [l.screenshotPolicyAllow, l.screenshotPolicyBlock];
    showM3ModalSheet(
      context,
      title: l.appearanceScreenshotPolicyTitle,
      children: [
        for (var i = 0; i < policyCodes.length; i++)
          ListTile(
            title: Text(policyLabels[i]),
            trailing: policyCodes[i] == settings.screenshotPolicy
                ? Icon(MdiIcons.check, color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () {
              notifier.setScreenshotPolicy(policyCodes[i]);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }
}

// Helper widget for color scheme presets.
//
// A miniature of the app drawn in the preset's own colors rather than an
// abstract swatch: a title, two content lines in the scheme's secondary, and
// the primary block parked in the corner. The mockup is the only way to judge
// how a scheme's roles interact before committing to it.
class _SchemePreset extends StatelessWidget {
  const _SchemePreset({
    required this.name,
    required this.isActive,
    required this.onTap,
  });

  final String name;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cs = colorSchemeFor(name, brightness);
    return GestureDetector(
      onTap: onTap,
      // 4 rather than 8: this is one side of the gap two cards share, and the
      // pair of them is the 8 the row of swatches wants -- wide enough to read
      // as separate cards, tight enough to read as one set.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 116,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: presetSurfaceFor(
                  name,
                  brightness,
                  amoled: AmoledMode.of(context),
                ),
                borderRadius: BorderRadius.circular(16),
                // Neutral on every card: the outline just defines the swatch
                // against the settings background, and selection is announced
                // by the badge rather than by a colored ring.
                border: Border.all(
                  color: isActive ? cs.outline : cs.outlineVariant,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 8,
                    child: Text(
                      'Abc',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // The two content lines: a short one above a longer one,
                  // both left aligned like a paragraph.
                  Positioned(
                    left: 0,
                    top: 52,
                    child: _PresetBar(width: 29, color: cs.secondary),
                  ),
                  Positioned(
                    left: 0,
                    top: 64,
                    child: _PresetBar(width: 50, color: cs.secondary),
                  ),
                  // The scheme's primary, bottom-right of the mockup.
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  if (isActive)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(
                        Icons.check_circle,
                        size: 20,
                        color: cs.primary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 6px-tall rounded rule standing in for a line of text in the mini UI.
class _PresetBar extends StatelessWidget {
  const _PresetBar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// Extension for capitalizing strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}