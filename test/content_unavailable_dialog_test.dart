import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/features/library/widgets/content_unavailable_dialog.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// The Kotatsu-style "Content unavailable" sheet. These pin the choice it
/// hands the reader: "Find on other sources" resolves true so the caller can
/// open the Alternatives search, Close resolves null, and the cover renders
/// through the app's CachedMangaImage (the referer-aware pipeline sources
/// actually use).
void main() {
  Widget host({ValueChanged<bool?>? onResult}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await showContentUnavailableDialog(
                  context,
                  imageUrl: '',
                );
                // Escaping the async gap: the button is long gone by then, so
                // hand the value back through the test's callback instead.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onResult?.call(result);
                });
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the sheet with heading, choice and close', (tester) async {
    await tester.pumpWidget(host());

    await openDialog(tester);

    expect(find.text('Content unavailable'), findsOneWidget);
    expect(find.text('This manga\'s source is not installed on this device.'),
        findsOneWidget);
    expect(find.text('Find on other sources'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('Find on other sources resolves true and closes the sheet', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(host(onResult: (r) => result = r));

    await openDialog(tester);
    await tester.tap(find.text('Find on other sources'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.text('Content unavailable'), findsNothing);
  });

  testWidgets('Close resolves null and leaves the caller on screen', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(host(onResult: (r) => result = r));

    await openDialog(tester);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Content unavailable'), findsNothing);
  });
}