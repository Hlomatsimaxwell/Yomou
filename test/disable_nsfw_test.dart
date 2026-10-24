import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The settings load syncs the image cache, which asks path_provider where
  // to put its files. There is no plugin behind that channel in a test, so
  // the load errors before it can even assign state.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => '/tmp/opencode',
      );

  group('Disable NSFW', () {
    test('hides NSFW-flagged sources from the visible rows', () async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(sourcesProvider);

      await container
          .read(cacheSettingsProvider.notifier)
          .setDisableNsfw(true);

      final names = container
          .read(visibleSourceRowsProvider)
          .map((row) => row['name'])
          .toList();
      expect(names, isNot(contains('Manhwa18')));
      // A SFW source is untouched by the same gate. MangaDex stays too: the
      // reference flags a source NSFW only when its content type is hentai,
      // and MangaDex is a regular manga catalogue that merely carries some
      // adult titles -- it must survive "Disable NSFW" the way Kotatsu-Redo's
      // does.
      expect(names, contains('Manganato'));
      expect(names, contains('MangaDex'));
    });

    test('a flip made while the async load is still in flight sticks',
        () async {
      // The notifier starts its persisted load in the constructor without
      // awaiting it, and that load ends by assigning state. Without a gate in
      // the setters, a flip racing the load is silently overwritten -- the
      // switch appeared to do nothing. Setters must wait for the load to land.
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(sourcesProvider);

      // Construct and flip in the same breath: no settle delay.
      await container
          .read(cacheSettingsProvider.notifier)
          .setDisableNsfw(true);

      expect(container.read(cacheSettingsProvider).disableNsfw, isTrue);
      expect(container.read(disableNsfwProvider), isTrue);

      // The load that was in flight has since landed -- it may not have
      // reset the flip.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(container.read(cacheSettingsProvider).disableNsfw, isTrue);
    });

    test('the flip survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
      final first = ProviderContainer();
      addTearDown(first.dispose);
      await first.read(cacheSettingsProvider.notifier).setDisableNsfw(true);

      // A fresh container reads a fresh notifier, and the persisted value
      // must come back on. The load is asynchronous and only starts when the
      // notifier is first touched, so signal on the state's next event --
      // a settle delay here races the load and flips between passing and
      // failing on a busy machine.
      final second = ProviderContainer();
      addTearDown(second.dispose);
      final loadedFromPrefs = Completer<bool>();
      second.listen<CacheSettings>(
        cacheSettingsProvider,
        (previous, next) {
          if (!loadedFromPrefs.isCompleted) {
            loadedFromPrefs.complete(next.disableNsfw);
          }
        },
      );
      second.read(cacheSettingsProvider.notifier);
      expect(await loadedFromPrefs.future, isTrue);
    });
  });
}
