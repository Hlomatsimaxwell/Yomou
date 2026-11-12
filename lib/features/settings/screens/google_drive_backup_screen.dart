import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:yomou/core/backup/backup_restore.dart';
import 'package:yomou/core/backup/google_drive_config.dart';
import 'package:yomou/core/backup/kotatsu_backup.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// Cloud backup via Google Drive.
///
/// Uses Google Sign-In (OAuth) to obtain a Drive-scoped token, then the
/// Drive v3 REST API to upload/download backup files in the user's own
/// Drive. Works on Android and iOS once the OAuth client is configured in
/// Google Cloud Console.
class GoogleDriveBackupScreen extends ConsumerStatefulWidget {
  const GoogleDriveBackupScreen({super.key});

  @override
  ConsumerState<GoogleDriveBackupScreen> createState() =>
      _GoogleDriveBackupScreenState();
}

class _GoogleDriveBackupScreenState
    extends ConsumerState<GoogleDriveBackupScreen> {
  final _googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);

  static const _folderName = 'Yomou';
  static const _folderMimeType = 'application/vnd.google-apps.folder';

  GoogleSignInAccount? _account;
  drive.DriveApi? _drive;

  /// Id of the folder backups are written to, resolved lazily and cached for
  /// the session. Reset when the account changes: Drive ids are per account,
  /// and reusing one from a previous sign-in would fail with a 404.
  String? _folderId;

  /// Backups written before the folder existed sit in the root of My Drive.
  /// Move them across once per session so the root does not stay cluttered.
  bool _movedLegacyBackups = false;

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
      final account = await _googleSignIn.signInSilently();
      if (account == null || !mounted) return;
      final client = _AuthedClient(account);
      setState(() {
        _account = account;
        _drive = drive.DriveApi(client);
        _status = 'Signed in as ${account.email}';
      });
    } catch (_) {
      // Not signed in; leave the sign-in button visible.
    }
  }

  @override
  void dispose() {
    super.dispose();
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
      final account = await _googleSignIn.signIn();
      if (account == null) {
        if (mounted) setState(() => _status = 'Sign-in cancelled');
        return;
      }
      final client = _AuthedClient(account);
      final driveApi = drive.DriveApi(client);
      if (!mounted) return;
      setState(() {
        _account = account;
        _drive = driveApi;
        _folderId = null;
        _movedLegacyBackups = false;
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
    await _googleSignIn.signOut();
    if (!mounted) return;
    setState(() {
      _account = null;
      _drive = null;
      _folderId = null;
      _movedLegacyBackups = false;
      _remoteFiles = const [];
      _status = 'Signed out';
    });
  }

  Future<void> _listRemote() async {
    final driveApi = _drive;
    if (driveApi == null) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final res = await driveApi.files.list(
        // Folders can match "contains 'yomou'" too, and offering one for
        // restore would fail on download, so keep them out of the list.
        q: "name contains 'yomou' "
            "and mimeType != '$_folderMimeType' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id,name,modifiedTime,size)',
      );
      if (!mounted) return;
      setState(() {
        _remoteFiles = res.files ?? const [];
        _status = 'Found ${_remoteFiles.length} remote file(s)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'List error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Returns the id of the folder backups live in, creating it on first use.
  Future<String> _ensureFolder(drive.DriveApi driveApi) async {
    final cached = _folderId;
    if (cached != null) return cached;

    // drive.file only exposes files this app created, so listing is enough to
    // find a folder from an earlier session; no picker or broad scope needed.
    final existing = await driveApi.files.list(
      q: "name = '$_folderName' "
          "and mimeType = '$_folderMimeType' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    final matches = existing.files ?? const <drive.File>[];
    var id = matches.isEmpty ? null : matches.first.id;
    id ??= (await driveApi.files.create(
      drive.File()
        ..name = _folderName
        ..mimeType = _folderMimeType,
      $fields: 'id',
    ))
        .id;
    if (id == null) {
      throw StateError('Drive did not return an id for the backup folder');
    }
    _folderId = id;
    return id;
  }

  /// Moves backups from before the folder existed out of the Drive root.
  Future<void> _moveLegacyBackups(
    drive.DriveApi driveApi,
    String folderId,
  ) async {
    if (_movedLegacyBackups) return;
    _movedLegacyBackups = true;
    try {
      final res = await driveApi.files.list(
        q: "name contains 'yomou' and mimeType != '$_folderMimeType' "
            "and 'root' in parents and trashed = false",
        spaces: 'drive',
        $fields: 'files(id)',
      );
      for (final f in res.files ?? const <drive.File>[]) {
        final id = f.id;
        if (id == null) continue;
        await driveApi.files.update(
          drive.File(),
          id,
          addParents: folderId,
          removeParents: 'root',
          $fields: 'id',
        );
      }
    } catch (_) {
      // Best effort. A backup that cannot be moved stays where it is, which
      // still restores fine; failing the upload over it would be worse.
    }
  }

  Future<void> _backupNow() async {
    final driveApi = _drive;
    if (driveApi == null) return;
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
      final media = drive.Media(
        Stream.value(result.bytes),
        result.bytes.length,
        contentType: 'application/zip',
      );
      final folderId = await _ensureFolder(driveApi);
      await _moveLegacyBackups(driveApi, folderId);
      final file = drive.File()
        ..name = name
        ..parents = [folderId];
      await driveApi.files.create(file, uploadMedia: media);
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
    final driveApi = _drive;
    if (driveApi == null || f.id == null) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final media = await driveApi.files.get(
        f.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }
      if (!mounted) return;
      final parsed = KotatsuBackupCodec.import(Uint8List.fromList(bytes));
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
                Text(_status!,
                    style: TextStyle(color: color.onSurfaceVariant)),
              ],
              if (_remoteFiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Remote backups',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                for (final f in _remoteFiles)
                  ListTile(
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// http.Client that injects the signed-in account's auth headers.
class _AuthedClient extends http.BaseClient {
  _AuthedClient(this._account);

  final GoogleSignInAccount _account;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _account.authHeaders;
    request.headers.addAll(headers);
    return _inner.send(request);
  }
}
