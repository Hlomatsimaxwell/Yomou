/// Vocabulary and timing shared by the automatic-backup settings UI and the
/// scheduler, so the label a user picks and the interval it stands for cannot
/// drift apart.
///
/// The scheduler runs when the app is opened, not from a background task, so
/// these are minimum gaps between runs rather than guarantees.
const backupFrequencyOptions = <String, String>{
  '6h': 'Every 6 hours',
  '1d': 'Every day',
  '2d': 'Every 2 days',
  '1w': 'Once per week',
  '2w': 'Twice per month',
  '1m': 'Once per month',
};

String backupFrequencyLabel(String code) => backupFrequencyOptions[code] ?? code;

/// Whether an automatic backup is due.
///
/// A missing timestamp means one has never run. A timestamp in the future
/// means the device clock moved backwards; treat that as due rather than
/// letting the schedule stall until the clock catches up.
bool isBackupDue({
  required int lastBackupAt,
  required String frequency,
  DateTime? now,
}) {
  if (lastBackupAt <= 0) return true;
  final at = now ?? DateTime.now();
  final elapsed =
      at.difference(DateTime.fromMillisecondsSinceEpoch(lastBackupAt));
  if (elapsed < Duration.zero) return true;
  return elapsed >= backupIntervalFor(frequency);
}

/// Wall-clock interval for a stored frequency code. Unknown codes fall back to
/// the default frequency instead of throwing, so a value written by a future
/// build cannot wedge the schedule.
Duration backupIntervalFor(String code) {
  switch (code) {
    case '6h':
      return const Duration(hours: 6);
    case '2d':
      return const Duration(days: 2);
    case '1w':
      return const Duration(days: 7);
    case '2w':
      return const Duration(days: 14);
    case '1m':
      return const Duration(days: 30);
    case '1d':
    default:
      return const Duration(days: 1);
  }
}
