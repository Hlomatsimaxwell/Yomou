import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import 'package:yomou/core/backup/backup_restore.dart';
import 'package:yomou/core/backup/google_drive_config.dart';
import 'package:yomou/core/backup/google_drive_service.dart';
import 'package:yomou/core/backup/kotatsu_backup.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/settings/widgets/automatic_backup_section.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// Cloud backup via Google Drive.
///
/// Signs in with Google, then uploads/downloads backup files in a `Yomou`
/// folder in the user's own Drive. The Drive calls themselves live in
/// [GoogleDriveService] so the automatic backup that runs on launch can use
/// them without this screen being open.
class GoogleDriveBackupScreen extends ConsumerStatefulWidget {
  const GoogleDriveBackupScreen({super.key});

  @override
  ConsumerState<GoogleDriveBackupScreen> createState() =>
      _GoogleDriveBackupScreenState();
}

class _GoogleDriveBackupScreenState
    extends ConsumerState<GoogleDriveBackupScreen> {
  final _drive = GoogleDriveService.instance;

  GoogleSignInAccount? _account;

  /// True until the native config check in [_init] has answered. Keeping the
  /// button disabled across that gap stops a tap on iOS from reaching the
  /// native SDK before we know a client ID exists.
  bool _busy = true;
  bool _signInConfigured = true;
  String? _status;
  List<drive.File> _remoteFiles = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final configured = await GoogleDriveConfig.isSignInConfigured();
    if (!mounted) return;
    setState(() {
      _signInConfigured = configured;
      _busy = false;
    });
    // Restoring a session also goes through the native SDK; skip it when the
    // client is missing so it cannot raise the same uncatchable exception.
    if (configured) await _tryRestore();
  }

  Future<void> _tryRestore() async {
    if (!_signInConfigured) return;
    try {
      final account = await _drive.restoreSession();
      if (account == null || !mounted) return;
      setState(() {
        _account = account;
        _status = 'Signed in as ${account.email}';
      });
    } catch (_) {
      // Not signed in; leave the sign-in button visible.
    }
  }

  Future<void> _signIn() async {
    if (!_signInConfigured) {
      await _showSetupRequired();
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final account = await _drive.signIn();
      if (account == null) {
        if (mounted) setState(() => _status = 'Sign-in cancelled');
        return;
      }
      if (!mounted) return;
      setState(() {
        _account = account;
        _status = 'Signed in as ${account.email}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Sign-in error: $e');
      // Surface the error so it is not missed (e.g. missing OAuth client
      // config shows up as a PlatformException here).
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign-in failed'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showSetupRequired() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Google Sign-In needs setup'),
        content: const SingleChildScrollView(
          child: Text(
            'This iOS build has no Google OAuth client, so the native SDK '
            'would stop the app instead of opening the sign-in sheet.\n\n'
            'Create an OAuth client ID of type iOS for bundle ID '
            'com.hlomatsi.yomou in Google Cloud Console, then add these to '
            'ios/Runner/Info.plist:\n\n'
            'GIDClientID = your iOS client ID\n'
            'CFBundleURLSchemes = com.googleusercontent.apps.<the part of '
            'the client ID before .apps.googleusercontent.com>\n\n'
            'See GOOGLE_DRIVE_SETUP.md for the full steps.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await _drive.signOut();
    if (!mounted) return;
    setState(() {
      _account = null;
      _remoteFiles = const [];
      _status = 'Signed out';
    });
  }

  Future<void> _listRemote() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final files = await _drive.listBackups();
      if (!mounted) return;
      setState(() {
        _remoteFiles = files;
        _status = 'Found ${files.length} remote file(s)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'List error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupNow() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final favorites = await DatabaseHelper.instance.getFavorites();
      final bookmarks = await DatabaseHelper.instance.getAllBookmarks();
      final progress = await DatabaseHelper.instance.getAllReadingProgress();

      final result = KotatsuBackupCodec.export(
        favorites: favorites,
        bookmarks: bookmarks,
        readingProgress: progress,
      );
      if (result.exported == 0) {
        if (!mounted) return;
        setState(() => _status = 'Nothing to back up');
        return;
      }

      final name = 'yomou-${DateTime.now().millisecondsSinceEpoch}.bk.zip';
      await _drive.uploadBackup(bytes: result.bytes, name: name);

      final settings = ref.read(cacheSettingsProvider);
      if (settings.deleteOldBackups) {
        try {
          await _drive.pruneBackups(keep: settings.maxNumberOfBackups);
        } catch (_) {
          // Retention is housekeeping; the backup itself already succeeded.
        }
      }
      await ref
          .read(cacheSettingsProvider.notifier)
          .recordBackupSuccess(DateTime.now().millisecondsSinceEpoch);

      if (!mounted) return;
      setState(() => _status = 'Uploaded $name');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Backup error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(drive.File f) async {
    if (f.id == null) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final bytes = await _drive.downloadBackup(f.id!);
      if (!mounted) return;
      final parsed = KotatsuBackupCodec.import(bytes);
      final container = ProviderScope.containerOf(context, listen: false);
      await BackupRestore.applyTachiyomi(parsed);
      bumpHistoryRevision(container);
      bumpFavoritesRevision(container);
      if (!mounted) return;
      setState(() => _status = 'Restored ${f.name}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Restore error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: SettingsAppBar(title: l.googleDriveBackup, contentMargin: 24),
      body: CappedContentWidth(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          children: [
            Text(
              'Sign in with your Google account. Backups are stored in a '
              'Yomou folder in your own Drive, and Yomou can only see files '
              'it created there.',
              style: TextStyle(fontSize: 13, color: color.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (!_signInConfigured) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Google Sign-In is not configured in this build. Tap the '
                  'button for setup steps.',
                  style: TextStyle(fontSize: 12, color: color.onErrorContainer),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_account == null)
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
              )
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_circle),
                title: Text(_account!.displayName ?? _account!.email),
                subtitle: Text(_account!.email),
                trailing: TextButton(
                  onPressed: _busy ? null : _signOut,
                  child: const Text('Sign out'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _busy ? null : _listRemote,
                      child: const Text('List files'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _backupNow,
                      child: const Text('Back up now'),
                    ),
                  ),
                ],
              ),
              if (_status != null) ...[
                const SizedBox(height: 8),
                Text(
                  _status!,
                  style: TextStyle(color: color.onSurfaceVariant),
                ),
              ],
              if (_remoteFiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Remote backups',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                for (final f in _remoteFiles)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(f.name ?? ''),
                    subtitle: f.modifiedTime == null
                        ? null
                        : Text(
                            _formatDate(f.modifiedTime!),
                            style: TextStyle(
                              fontSize: 12,
                              color: color.onSurfaceVariant,
                            ),
                          ),
                    trailing: TextButton(
                      onPressed: _busy ? null : () => _restore(f),
                      child: const Text('Restore'),
                    ),
                  ),
              ],
            ],
            AutomaticBackupSection(signedIn: _account != null),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
