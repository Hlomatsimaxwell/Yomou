import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/changelog/changelog.dart';

/// The two shapes the parser must read without inventing anything: the
/// `## [version] - date` heading, `### Section`, and `- entry` bullets. The
/// rest of the file (the preamble, `[Unreleased]`, the `## Footnote` list) is
/// noise that must not leak into a release.
const _sample = '''
# Changelog

## [Unreleased]

### Changed
- Work in progress.

## [1.2.0] - 2026-11-01

### Added
- **A feature** that does a thing.
- Another one with `code`.

### Fixed
- A bug.

## [1.1.0+3] - 2026-10-11

### Added
- First.

## Footnote

Build & release tooling
- Not release notes.
''';

void main() {
  group('parseChangelog', () {
    test('returns releases newest first and ignores Unreleased and Footnote', () {
      final releases = parseChangelog(_sample);
      expect(releases.map((r) => r.version), ['1.2.0', '1.1.0']);
      expect(releases.every((r) => r.date != null), isTrue);
      // The Footnote bullets are not attached to any release.
      expect(
        releases.expand((r) => r.sections).expand((s) => s.entries),
        isNot(contains('Not release notes.')),
      );
    });

    test('keeps section order and entries as written', () {
      final release = parseChangelog(_sample).first;
      expect(release.date, '2026-11-01');
      expect(release.sections.map((s) => s.title), ['Added', 'Fixed']);
      expect(release.sections.first.entries, [
        '**A feature** that does a thing.',
        'Another one with `code`.',
      ]);
    });

    test('strips the build suffix so notes are per release, not per build', () {
      final release = parseChangelog(_sample).last;
      expect(release.version, '1.1.0');
      expect(release.date, '2026-10-11');
    });

    test('returns nothing for a changelog without releases', () {
      expect(parseChangelog('# Changelog\n\n## [Unreleased]\n'), isEmpty);
      expect(parseChangelog(''), isEmpty);
    });

    test('a release with no bullets is dropped rather than shown empty', () {
      final releases = parseChangelog('## [2.0.0] - 2026-12-01\n\n');
      expect(releases, isEmpty);
    });

    test('parses the real bundled changelog', () {
      final source = File('CHANGELOG.md').readAsStringSync();
      final releases = parseChangelog(source);
      expect(releases, isNotEmpty);
      final latest = releases.first;
      expect(latest.version, isNotEmpty);
      expect(latest.sections, isNotEmpty);
      // 1.1.0 is the release this feature ships with; its notes must survive.
      expect(releases.map((r) => r.version), contains('1.1.0'));
    });
  });
}
