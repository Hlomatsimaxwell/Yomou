import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// One section of a release's notes, e.g. "Added" or "Fixed".
class ChangelogSection {
  const ChangelogSection({required this.title, required this.entries});

  /// The raw heading text from the changelog ("Added", "Performance", ...).
  /// The UI maps the known ones to localized labels and falls back to this.
  final String title;

  final List<String> entries;
}

/// The notes for a single released version.
class ChangelogRelease {
  const ChangelogRelease({
    required this.version,
    this.date,
    required this.sections,
  });

  /// The name version without its build suffix (`1.0.0+1` is stored as `1.0.0`,
  /// because the notes are per release, not per build).
  final String version;

  /// The ISO date from the heading, when present.
  final String? date;

  final List<ChangelogSection> sections;

  bool get isEmpty => sections.isEmpty;
}

/// Parses the committed `CHANGELOG.md` into releases, newest first.
///
/// The file is the one source of truth for release notes, so the sheet can never
/// drift from what was actually shipped. Only the heading shapes the changelog
/// actually uses are read -- `## [x.y.z] - date`, `### Section`, `- entry` -- and
/// anything else (the `[Unreleased]` block, the `## Footnote` section, blank
/// lines) is ignored, so a stray line cannot break the start-up path that loads
/// this.
List<ChangelogRelease> parseChangelog(String source) {
  final releases = <ChangelogRelease>[];

  String? version;
  String? date;
  String? sectionTitle;
  var entries = <String>[];
  var sections = <ChangelogSection>[];

  void flushSection() {
    if (sectionTitle != null) {
      sections.add(ChangelogSection(title: sectionTitle!, entries: entries));
    }
    sectionTitle = null;
    entries = <String>[];
  }

  void flushRelease() {
    flushSection();
    if (version != null && sections.isNotEmpty) {
      releases.add(
        ChangelogRelease(version: version!, date: date, sections: sections),
      );
    }
    version = null;
    date = null;
    sections = <ChangelogSection>[];
  }

  final heading = RegExp(r'^## \[(.+?)\](?:\s*-\s*(.+))?$');

  for (final raw in source.split('\n')) {
    final line = raw.trimRight();

    if (line.startsWith('## ')) {
      flushRelease();
      final match = heading.firstMatch(line);
      if (match == null) continue; // e.g. "## Footnote"
      final tag = match.group(1)!;
      if (tag.toLowerCase() == 'unreleased') continue;
      version = tag.split('+').first;
      date = match.group(2)?.trim();
    } else if (line.startsWith('### ')) {
      flushSection();
      sectionTitle = line.substring(4).trim();
    } else if (line.startsWith('- ') && sectionTitle != null) {
      entries.add(line.substring(2).trim());
    }
  }
  flushRelease();

  return releases;
}

/// Loads and parses the bundled changelog.
Future<List<ChangelogRelease>> loadChangelog() async {
  final text = await rootBundle.loadString('CHANGELOG.md');
  return parseChangelog(text);
}

/// The notes to show for the running app version.
///
/// Matches on [versionName] exactly; when a build shipped without a matching
/// changelog entry (or the name was bumped but the notes were not written yet),
/// the newest documented release is used so the reader still sees something
/// rather than an empty sheet.
Future<ChangelogRelease?> changelogReleaseFor(String versionName) async {
  final releases = await loadChangelog();
  if (releases.isEmpty) return null;
  for (final release in releases) {
    if (release.version == versionName) return release;
  }
  return releases.first;
}

const String _seenVersionKey = 'changelog.lastSeenVersion';

/// The version whose notes were last shown (or last seen), or null on a build
/// that predates this feature.
Future<String?> readSeenVersion() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_seenVersionKey);
}

/// Records [version] as seen so its notes are not shown again.
Future<void> markVersionSeen(String version) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_seenVersionKey, version);
}
