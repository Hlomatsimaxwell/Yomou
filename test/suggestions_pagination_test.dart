import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/suggestions/providers/suggestions_provider.dart';

/// The Suggestions feed used to resolve every page up front. These cover the
/// load-more state machine: appending pages, stopping on an empty page, and
/// reloading from page 1. The page fetch is injected so the tests do not need
/// the source cache database or the WebView queue.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Manga manga(int i) => Manga(
        id: '$i',
        title: 'Manga $i',
        coverUrl: '',
        sourceId: 'test',
      );

  ProviderContainer containerWithPages(
    Map<int, List<Manga>> pages,
    List<int> requested, {
    String? expectedGenre,
  }) {
    return ProviderContainer(
      overrides: [
        // No sources needed: the injected fetcher ignores them.
        visibleSourceRowsProvider.overrideWith((ref) => []),
        suggestionsRefreshMinutesProvider.overrideWith((ref) => 60),
        suggestionPageFetcherProvider.overrideWith((ref) {
          return (sources, genre, {required int page}) async {
            expect(genre, expectedGenre);
            requested.add(page);
            return pages[page] ?? const <Manga>[];
          };
        }),
      ],
    );
  }

  test('loadMore appends pages and stops once a page comes back empty', () async {
    final requested = <int>[];
    final container = containerWithPages({
      1: [manga(1), manga(2)],
      2: [manga(3)],
    }, requested);
    addTearDown(container.dispose);

    final provider = suggestionsFeedProvider(null);
    final notifier = container.read(provider.notifier);

    var state = await container.read(provider.future);
    expect(state.items.map((m) => m.id), ['1', '2']);
    expect(state.page, 1);
    expect(state.hasMore, isTrue);
    expect(state.loadingMore, isFalse);

    await notifier.loadMore();
    state = container.read(provider).value!;
    expect(state.items.map((m) => m.id), ['1', '2', '3']);
    expect(state.page, 2);
    expect(state.hasMore, isTrue);
    expect(state.loadingMore, isFalse);

    // Page 3 is empty: the feed is exhausted and hasMore flips off.
    await notifier.loadMore();
    state = container.read(provider).value!;
    expect(state.items.map((m) => m.id), ['1', '2', '3']);
    expect(state.page, 3);
    expect(state.hasMore, isFalse);

    // No further fetch once exhausted.
    await notifier.loadMore();
    expect(requested, [1, 2, 3]);
  });

  test('reload discards appended pages and returns to page 1', () async {
    final requested = <int>[];
    final container = containerWithPages({
      1: [manga(1), manga(2)],
      2: [manga(3)],
    }, requested);
    addTearDown(container.dispose);

    final provider = suggestionsFeedProvider(null);
    final notifier = container.read(provider.notifier);
    await container.read(provider.future);
    await notifier.loadMore();
    expect(container.read(provider).value!.items, hasLength(3));

    await notifier.reload();
    final state = container.read(provider).value!;
    expect(state.items.map((m) => m.id), ['1', '2']);
    expect(state.page, 1);
    expect(state.hasMore, isTrue);
    expect(requested, [1, 2, 1]);
  });

  test('pages de-duplicate across sources by id and title', () async {
    final requested = <int>[];
    final container = containerWithPages({
      1: [manga(1)],
      // Same source+id and same normalized title: both dropped. A different
      // source with the same bare id is a different series and stays.
      2: [
        Manga(id: '1', title: 'Elsewhere', coverUrl: '', sourceId: 'test'),
        Manga(id: '2', title: 'Manga 1', coverUrl: '', sourceId: 'other'),
        manga(3),
      ],
    }, requested);
    addTearDown(container.dispose);

    final provider = suggestionsFeedProvider(null);
    final notifier = container.read(provider.notifier);
    await container.read(provider.future);
    await notifier.loadMore();

    expect(
      container.read(provider).value!.items.map((m) => m.id),
      ['1', '3'],
    );
  });

  test('the selected genre is forwarded as the family argument', () async {
    final requested = <int>[];
    final container = containerWithPages({
      1: [manga(7)],
    }, requested, expectedGenre: 'Action');
    addTearDown(container.dispose);

    final state =
        await container.read(suggestionsFeedProvider('Action').future);
    expect(state.items.single.id, '7');
    expect(requested, [1]);
  });
}
