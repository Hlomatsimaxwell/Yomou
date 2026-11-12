import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/backup/backup_schedule.dart';
import 'package:yomou/core/backup/periodic_backup_service.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';

void main() {
  group('backup frequency', () {
    test('every code has a label', () {
      for (final code in backupFrequencyOptions.keys) {
        expect(backupFrequencyLabel(code), isNot(code));
      }
    });

    test('the interval matches what the label promises', () {
      expect(backupIntervalFor('6h'), const Duration(hours: 6));
      expect(backupIntervalFor('1d'), const Duration(days: 1));
      expect(backupIntervalFor('2d'), const Duration(days: 2));
      expect(backupIntervalFor('1w'), const Duration(days: 7));
      expect(backupIntervalFor('2w'), const Duration(days: 14));
      expect(backupIntervalFor('1m'), const Duration(days: 30));
    });

    test('an unknown code falls back instead of throwing', () {
      expect(backupIntervalFor('fortnight-ish'), const Duration(days: 1));
      expect(backupFrequencyLabel('fortnight-ish'), 'fortnight-ish');
    });
  });

  group('isBackupDue', () {
    final now = DateTime(2026, 1, 10, 12);
    int at(Duration ago) => now.subtract(ago).millisecondsSinceEpoch;

    test('is due when no backup has ever run', () {
      expect(isBackupDue(lastBackupAt: 0, frequency: '1d', now: now), isTrue);
    });

    test('is not due inside the interval', () {
      expect(
        isBackupDue(
          lastBackupAt: at(const Duration(hours: 6)),
          frequency: '1d',
          now: now,
        ),
        isFalse,
      );
    });

    test('is due once the interval has passed', () {
      expect(
        isBackupDue(
          lastBackupAt: at(const Duration(hours: 25)),
          frequency: '1d',
          now: now,
        ),
        isTrue,
      );
    });

    test('is due when the device clock moved backwards', () {
      expect(
        isBackupDue(
          lastBackupAt: at(const Duration(hours: -2)),
          frequency: '1d',
          now: now,
        ),
        isTrue,
      );
    });
  });

  test('a disabled schedule does nothing', () async {
    final result = await PeriodicBackupService.maybeRun(
      settings: CacheSettings.defaults(),
    );
    expect(result.outcome, PeriodicBackupOutcome.disabled);
    expect(result.uploaded, isFalse);
  });
}
