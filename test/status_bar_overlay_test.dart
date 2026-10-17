import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';

/// The status bar is drawn by the OS over an edge-to-edge app, and the colour
/// of its icons comes from the `SystemUiOverlayStyle` an `AppBar` annotates over
/// the top of the screen. The app's bars are transparent so the scaffold shows
/// through them -- but Flutter picks the icon colour by estimating the bar's
/// *own* background, and a transparent colour estimates as dark, so a light
/// screen was handed white icons over a white scaffold and the status bar
/// vanished. The style is named from the theme's brightness instead.
void main() {
  Future<SystemUiOverlayStyle> appBarStyle(
    WidgetTester tester,
    ThemeMode mode,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            final theme = ref.watch(themeNotifierProvider);
            return MaterialApp(
              theme: theme.lightTheme,
              darkTheme: theme.darkTheme,
              themeMode: mode,
              home: Scaffold(appBar: AppBar(title: const Text('x'))),
            );
          },
        ),
      ),
    );
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    return region.value;
  }

  testWidgets('a light theme asks for dark status bar icons', (tester) async {
    final style = await appBarStyle(tester, ThemeMode.light);

    // Dark icons on the light scaffold: Android reads iconBrightness, iOS reads
    // barBrightness (the opposite sense, since it names the bar's own colour).
    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.statusBarBrightness, Brightness.light);
    expect(style.statusBarColor, Colors.transparent);
  });

  testWidgets('a dark theme asks for light status bar icons', (tester) async {
    final style = await appBarStyle(tester, ThemeMode.dark);

    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark);
    expect(style.statusBarColor, Colors.transparent);
  });
}
