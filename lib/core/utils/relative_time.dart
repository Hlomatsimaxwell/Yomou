import 'package:yomou/l10n/generated/app_localizations.dart';

/// Formats [time] as a localized relative label ("Just now", "5 minutes ago",
/// "2 days ago"...). Future timestamps are treated as "Just now".
String relativeTimeLabel(AppLocalizations l, DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return l.backupJustNow;
  if (diff.inMinutes < 60) return l.backupMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.backupHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l.backupDaysAgo(diff.inDays);
  if (diff.inDays < 30) return l.backupWeeksAgo(diff.inDays ~/ 7);
  if (diff.inDays < 365) return l.backupMonthsAgo(diff.inDays ~/ 30);
  return l.backupYearsAgo(diff.inDays ~/ 365);
}