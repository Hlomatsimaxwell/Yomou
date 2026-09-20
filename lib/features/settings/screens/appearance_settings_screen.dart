import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/core/security/app_lock.dart';
import 'package:yomou/core/security/pin_lock_screen.dart';
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
      appBar: SettingsAppBar(title: l.appearanceTitle),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Color Scheme Carousel
          M3SectionHeader(title: l.appearanceColorScheme),
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _SchemePreset(
                  name: 'Totoro',
                  palette: schemePalettes[AppColorScheme.totoro]!,
                  isActive: settings.colorScheme == 'Totoro',
                  onTap: () => notifier.setColorScheme('Totoro'),
                ),
                _SchemePreset(
                  name: 'Dynamic',
                  palette: schemePalettes[AppColorScheme.dynamic]!,
                  isActive: settings.colorScheme == 'Dynamic',
                  onTap: () => notifier.setColorScheme('Dynamic'),
                ),
                _SchemePreset(
                  name: 'Expressive',
                  palette: schemePalettes[AppColorScheme.expressive]!,
                  isActive: settings.colorScheme == 'Expressive',
                  onTap: () => notifier.setColorScheme('Expressive'),
                ),
                _SchemePreset(
                  name: 'Miku',
                  palette: schemePalettes[AppColorScheme.miku]!,
                  isActive: settings.colorScheme == 'Miku',
                  onTap: () => notifier.setColorScheme('Miku'),
                ),
                _SchemePreset(
                  name: 'Monochrome',
                  palette: schemePalettes[AppColorScheme.monochrome]!,
                  isActive: settings.colorScheme == 'Monochrome',
                  onTap: () => notifier.setColorScheme('Monochrome'),
                ),
              ],
            ),
          ),

          // Theme Options
          M3SectionHeader(title: l.appearanceSectionThemeOptions),
          ListTile(
            title: Text(l.appearanceThemeTitle),
            subtitle: Text(_themeModeLabel(l, settings.themeMode)),
            onTap: () => _showThemeModeSelector(context, ref, settings, notifier),
          ),
          ListTile(
            title: Text(l.appearanceLanguageTitle),
            subtitle: Text(_languageLabel(l, settings.language)),
            onTap: () => _showLanguageSelector(context, ref, settings, notifier),
          ),

          // Manga List Section
          M3SectionHeader(title: l.appearanceSectionMangaList),
          ListTile(
            title: Text(l.appearanceListModeTitle),
            subtitle: Text(_listModeLabel(l, settings.listMode)),
            onTap: () => _showListModeSelector(context, ref, settings, notifier),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.appearanceGridSize(settings.gridSize.round())),
                Slider(
                  value: settings.gridSize,
                  min: 50,
                  max: 150,
                  onChanged: (v) => notifier.setGridSize(v),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(l.appearanceQuickFilters),
            value: settings.showQuickFilters,
            onChanged: (_) => notifier.toggleBool('showQuickFilters'),
          ),
          SwitchListTile(
            title: Text(l.appearanceReadingProgress),
            value: settings.showReadingProgress,
            onChanged: (_) => notifier.toggleBool('showReadingProgress'),
          ),
          SwitchListTile(
            title: Text(l.appearanceBadges),
            value: settings.showListBadges,
            onChanged: (_) => notifier.toggleBool('showListBadges'),
          ),

          // Details Section
          M3SectionHeader(title: l.appearanceDetails),
          SwitchListTile(
            title: Text(l.appearanceCollapseDescription),
            value: settings.collapseDescription,
            onChanged: (_) => notifier.toggleBool('collapseDescription'),
          ),
          ListTile(
            title: Text(l.appearanceDefaultTabTitle),
            subtitle: Text(_tabLabel(l, settings.defaultTab)),
            onTap: () => _showDefaultTabSelector(context, ref, settings, notifier),
          ),

          // Main Screen Section
          M3SectionHeader(title: l.appearanceSectionMainScreen),
          ListTile(
            title: Text(l.appearanceSearchSuggestionsTitle),
            subtitle: Text(_suggestionSummary(context, settings)),
            onTap: () => _showSearchSuggestionsSheet(context, ref, settings, notifier),
          ),
          ListTile(
            title: Text(l.appearanceMainSectionsTitle),
            subtitle: Text(l.appearanceMainSectionsSubtitle),
            onTap: () => _showMainSectionsSheet(context, ref, settings, notifier),
          ),
          SwitchListTile(
            title: Text(l.appearanceFloatingContinue),
            value: settings.showFloatingContinueButton,
            onChanged: (_) => notifier.toggleBool('showFloatingContinueButton'),
          ),
          SwitchListTile(
            title: Text(l.appearanceNavLabels),
            value: settings.showNavLabels,
            onChanged: (_) => notifier.toggleBool('showNavLabels'),
          ),
          SwitchListTile(
            title: Text(l.appearanceFloatingNav),
            value: settings.useFloatingNavBar,
            onChanged: (_) => notifier.toggleBool('useFloatingNavBar'),
          ),
          SwitchListTile(
            title: Text(l.appearancePinNav),
            subtitle: Text(l.appearancePinNavSubtitle),
            value: settings.pinNavUiOnScroll,
            onChanged: (_) => notifier.toggleBool('pinNavUiOnScroll'),
          ),
          SwitchListTile(
            title: Text(l.appearanceExitConfirmation),
            subtitle: Text(l.appearanceExitConfirmationSubtitle),
            value: settings.exitConfirmation,
            onChanged: (_) => notifier.toggleBool('exitConfirmation'),
          ),
          SwitchListTile(
            title: Text(l.appearanceRecentShortcuts),
            value: settings.showRecentShortcuts,
            onChanged: (_) => notifier.toggleBool('showRecentShortcuts'),
          ),
          SwitchListTile(
            title: Text(l.appearanceHideNsfwShortcuts),
            value: settings.hideNsfwFromShortcuts,
            onChanged: (_) => notifier.toggleBool('hideNsfwFromShortcuts'),
          ),

          // Privacy Section
          M3SectionHeader(title: l.appearancePrivacy),
          SwitchListTile(
            title: Text(l.appearanceProtectApp),
            subtitle: Text(l.appearanceProtectAppSubtitle),
            value: settings.protectApp,
            onChanged: (v) => _handleProtectAppToggle(context, ref, v),
          ),
          ListTile(
            title: Text(l.appearanceScreenshotPolicyTitle),
            subtitle: Text(settings.screenshotPolicy),
            onTap: () => _showScreenshotPolicySheet(context, ref, settings, notifier),
          ),

          const SizedBox(height: 24),
        ],
      ),
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
          ? Icon(RemixIcons.check_line, color: Theme.of(context).colorScheme.primary)
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
                ? Icon(RemixIcons.check_line, color: Theme.of(context).colorScheme.primary)
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
          ? Icon(RemixIcons.check_line, color: Theme.of(context).colorScheme.primary)
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
                ? Icon(RemixIcons.check_line, color: Theme.of(context).colorScheme.primary)
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
          ? const Color(0xFF1C1C1E)
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
                ? Icon(RemixIcons.check_line, color: Theme.of(context).colorScheme.primary)
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

// Helper widget for color scheme presets
class _SchemePreset extends StatelessWidget {
  const _SchemePreset({
    required this.name,
    required this.palette,
    required this.isActive,
    required this.onTap,
  });

  final String name;
  final SchemePalette palette;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isMonochrome = name == 'Monochrome';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 82,
        height: 90,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? cs.secondaryContainer : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? cs.primary : cs.outlineVariant,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isActive)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary,
                ),
                child: Icon(
                  RemixIcons.check_line,
                  size: 18,
                  color: cs.onPrimary,
                ),
              )
            else
              _TwoToneBadge(
                // Monochrome's two-tone pair flips with brightness:
                // white/gray on dark, black/gray on light.
                primary: isMonochrome
                    ? (dark ? Colors.white : Colors.black)
                    : palette.accent,
                secondary: isMonochrome
                    ? (dark ? const Color(0xFF888888) : const Color(0xFF666666))
                    : (palette.secondary ?? palette.accentLight),
              ),
            const SizedBox(height: 6),
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

/// A 28px circular badge split vertically into the preset's primary and
/// secondary/container colors.
class _TwoToneBadge extends StatelessWidget {
  const _TwoToneBadge({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(child: Container(color: primary)),
          Expanded(child: Container(color: secondary)),
        ],
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