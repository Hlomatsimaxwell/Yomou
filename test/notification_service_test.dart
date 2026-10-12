import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/notifications/notification_service.dart';

/// The backup/export/import result notification must never break the flow that
/// triggered it: it posts on a silent channel, and when the platform plugin is
/// unavailable (tests, or a device that denied notification permission) it
/// completes quietly instead of throwing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backup result notification is a safe no-op without the plugin', () async {
    await NotificationService.instance.showBackupResultNotification(
      id: NotificationService.exportResultNotificationId,
      title: 'Backup saved',
      body: '3 manga exported',
    );
  });

  test('import scan progress notification is a safe no-op without the plugin',
      () async {
    await NotificationService.instance.showBackupProgress(
      id: NotificationService.importResultNotificationId,
      title: 'Looking for missing titles',
      body: '1/4 scanned',
      current: 1,
      total: 4,
    );
    await NotificationService.instance.cancelBackupProgress(
      id: NotificationService.importResultNotificationId,
    );
  });

  test('import and export use distinct notification ids', () {
    expect(
      NotificationService.exportResultNotificationId,
      isNot(NotificationService.importResultNotificationId),
    );
  });
}