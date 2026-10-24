import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/notifications/suggestion_ranking.dart';

void main() {
  group('almostEquals (the reference tag matcher, verbatim)', () {
    test('case, spacing and apostrophes do not break a match', () {
      expect(almostEquals('Action', 'action'), isTrue);
      expect(almostEquals(' action ', 'Action'), isTrue);
      expect(almostEquals('shounen', 'Shonen'), isTrue);
    });

    test(
        'the threshold is over average length, so a short edit still matches',
        () {
      // Reference worker matches this too: 'shounen' finds 'shounen ai' at
      // threshold 0.4 (distance 3 over an average length of 8.5 is 0.35).
      expect(almostEquals('shounen', 'shounen ai'), isTrue);
      // ' action ' vs 'Action': the padding costs one edit over 7 characters.
      expect(almostEquals('a Ctions', 'actions'), isTrue);
    });

    test('unrelated tags never match', () {
      // Distance 6 over an average length 6 — a full miss.
      expect(almostEquals('action', 'comedy'), isFalse);
      // Even the shared substring 'man' cannot rescue this pair.
      expect(almostEquals('webtoon', 'manhwa'), isFalse);
    });

    test('threshold 0 degrades to the case-insensitive exact match', () {
      expect(almostEquals('Drama', 'drama', threshold: 0), isTrue);
      expect(almostEquals('Drama', 'dramas', threshold: 0), isFalse);
      expect(almostEquals('dramas', 'Drama', threshold: 0.2), isTrue);
    });
  });

  group('TagStatistics.rarity (the reference formula)', () {
    late TagStatistics stats;

    setUp(() {
      // Corpus of 10 manga: 'action' on 6 of them, 'villainess' on 1,
      // 'isekai' on none.
      stats = TagStatistics.fromRows([
        for (var i = 0; i < 6; i++)
          {'tags': '["action","fantasy"]', 'mangaId': 'a$i'},
        {'tags': '["villainess"]', 'mangaId': 'x'},
        {'tags': '[]', 'mangaId': 'untagged1'},
        {'tags': null, 'mangaId': 'untagged2'},
      ]);
    });

    test('rarity is ln((total + 1)/(frequency + 1)) + 1', () {
      // total counts the manga that carry tags: 6 + 1 here.
      expect(stats.total, 7);
      final expectedAction = (log(8 / 7) + 1).toStringAsFixed(6);
      expect(stats.rarity('action').toStringAsFixed(6), expectedAction);
    });

    test('unseen tags are rare, not infinite; smoothing keeps them finite', () {
      final expected = (log(8 / 1) + 1).toStringAsFixed(6);
      expect(stats.rarity('isekai').toStringAsFixed(6), expected);
    });

    test('matching ignores case and surrounding whitespace', () {
      expect(stats.frequency(' Action '), 6);
      expect(stats.frequency('villainess'), 1);
    });
  });

  group('distinctiveTags (TF-IDF over the reader\'s own tags)', () {
    test(
        'a rare recurring tag outranks a frequent common one; singletons trail',
        () {
      // 'action': on 8 of the reader's manga, but rare nowhere —
      // 'villainess': on 3, but unseen in the corpus.
      final seedTags = [
        for (var i = 0; i < 8; i++) 'action',
        for (var i = 0; i < 3; i++) 'villainess',
        'time travel',
      ];
      final stats = TagStatistics.fromRows([
        for (var i = 0; i < 40; i++) {'tags': '["action"]'},
        {'tags': '["fantasy"]'},
      ]);
      final ranked = distinctiveTags(
        seedTags,
        stats.rarity,
        10,
      );
      // recurring tier first: 3 * rarity(villainess) beats 8 * rarity(action)
      // because rarity(action) over a mostly-action corpus is near its floor.
      expect(ranked.first, 'villainess');
      expect(ranked[1], 'action');
      // a tag on a single manga never leads, however rare it is here.
      expect(ranked[2], 'time travel');
    });

    test('the original spelling survives, the grouping does not', () {
      final ranked = distinctiveTags(
        ['Romance', 'romance', 'ROMANCE', 'Supernatural'],
        (_) => 5.0,
        10,
      );
      expect(ranked, ['Romance', 'Supernatural']);
    });

    test('the limit is honoured by both tiers', () {
      final ranked = distinctiveTags(
        [for (var i = 0; i < 12; i++) 't$i', for (var i = 0; i < 12; i++) 't$i'],
        (_) => 1.0,
        5,
      );
      expect(ranked.length, 5);
    });
  });

  group('isDropped (opened, barely read, left for weeks)', () {
    final now = DateTime(2026, 10, 24, 12);

    test('a 5%-read title untouched for 21 days counts as dropped', () {
      final d = now.subtract(const Duration(days: 22));
      expect(isDropped(0.05, d, now), isTrue);
      expect(isDropped(0.0, d, now), isTrue); // opened, never actually read
    });

    test('reading past a tenth rescues a title', () {
      final d = now.subtract(const Duration(days: 30));
      expect(isDropped(0.11, d, now), isFalse);
    });

    test('a recently touched 2%-read title is paused, not dropped', () {
      final d = now.subtract(const Duration(days: 3));
      expect(isDropped(0.02, d, now), isFalse);
    });

    test('the day boundary is exclusive: 21 days to the hour is a pause', () {
      final exactly = now.subtract(droppedAfter);
      expect(isDropped(0.02, exactly, now), isFalse);
      expect(isDropped(0.02, exactly.subtract(const Duration(days: 1)), now),
          isTrue);
    });

    test('unknown progress or last-read time is never evidence', () {
      expect(isDropped(null, now.subtract(const Duration(days: 60)), now),
          isFalse);
      expect(isDropped(0.05, null, now), isFalse);
    });
  });

  group('computeRelevance (the reference weighted overlap, squared)', () {
    test('earlier ranked tags count heavier, and the score is squared', () {
      final ranked = ['villainess', 'romance', 'action'];
      final close = computeRelevance(
        ['villainess', 'romance'],
        ranked,
      ); // weight = 3 + 2 = 5; max = (7 - 2) * 2 / 2 = 5 → (1)^2
      final loose = computeRelevance(
        ['villainess', 'isekai'],
        ranked,
      ); // weight = 3; max = 5 → (0.6)^2
      expect(close, 1.0);
      expect(loose.toStringAsFixed(4), '0.3600');
      expect(close > loose, isTrue);
    });

    test('no echo is a plain zero', () {
      expect(computeRelevance(['horror'], ['villainess', 'romance']), 0);
      expect(computeRelevance(['villainess'], <String>[]), 0);
    });

    test('fuzzy matching through almostEquals closes over source spellings',
        () {
      // 'Shoujo Ai' sits within threshold of the ranked 'shoujo ai '.
      final relevance = computeRelevance(
        ['Shoujo Ai', 'unknown tag'],
        ['shoujo ai ', 'romance'],
      );
      expect(relevance, greaterThan(0));
      final exact = computeRelevance(['romance'], ['shoujo ai ', 'romance']);
      // 'romance' sits second in the ranked list, so half the maximum
      // weight — squared, 0.25.
      expect(exact, 0.25);
    });
  });

  group('pickAnnounceIndex (one random title from the best third)', () {
    test('the bound is a third, rounded down, never empty', () {
      final rng = Random(7);
      for (var i = 0; i < 200; i++) {
        expect(pickAnnounceIndex(9, rng), lessThan(3));
        expect(pickAnnounceIndex(2, rng), lessThan(1));
        expect(pickAnnounceIndex(1, rng), isZero);
        expect(pickAnnounceIndex(4, rng), lessThan(1));
      }
    });

    test('a short list still covers its whole best third', () {
      final rng = Random(11);
      final picked = <int>{};
      for (var i = 0; i < 100; i++) {
        picked.add(pickAnnounceIndex(3, rng));
      }
      // (3 / 3) = 1 → only index 0 could be drawn, twice the third of it. So
      // this asserts the never-empty guard rather than a spread.
      expect(picked, {0});
    });

    test('nothing in, nothing out', () {
      expect(pickAnnounceIndex(0, Random(1)), -1);
    });
  });
}
