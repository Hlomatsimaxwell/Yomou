import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';

/// ThemeData only picks an icon color from the brightness handed to its own
/// constructor. The base theme in this app is always built light and then
/// re-brightened via copyWith, which does not revisit iconTheme -- so without
/// an explicit override every bare Icon(...) stayed black in dark mode and
/// vanished against the black scaffold.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default icon color follows the theme brightness', () async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final bundle = container.read(themeNotifierProvider);

    expect(bundle.darkTheme.iconTheme.color, Colors.white);
    expect(bundle.lightTheme.iconTheme.color, const Color(0xFF1C1B1F));
  });
}
