import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// The signed-in Google account together with the Drive operations backups
/// need.
///
/// This used to live inside `GoogleDriveBackupScreen`, which meant the
/// automatic-backup scheduler could not reach it: a background run has no
/// `BuildContext` and must not depend on a mounted widget. One shared instance
/// keeps the sign-in state in a single place, so the screen and the scheduler
/// cannot disagree about who is signed in.
class GoogleDriveService {
  GoogleDriveService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(scopes: const [drive.DriveApi.driveFileScope]);

  /// Shared by the backup screen and the scheduler.
  static final GoogleDriveService instance = GoogleDriveService();

  static const folderName = 'Yomou';
  static const folderMimeType = 'application/vnd.google-apps.folder';

  final GoogleSignIn _googleSignIn;

  GoogleSignInAccount? _account;
  drive.DriveApi? _api;
  String? _folderId;

  /// Backups written before the folder existed sit in the root of My Drive.
  /// Moving them is a best-effort, once-per-session tidy-up.
  bool _movedLegacyBackups = false;

  GoogleSignInAccount? get account => _account;

  bool get isSignedIn => _api != null;

  /// Restores a previous sign-in without showing any UI. Returns null when
  /// there is nothing stored, or when the platform declines to restore.
  Future<GoogleSignInAccount?> restoreSession() async {
    final existing = _account;
    if (existing != null && _api != null) return existing;
    final account = await _googleSignIn.signInSilently();
    if (account == null) return null;
    _account = account;
    _api = drive.DriveApi(_AuthedClient(account));
    return account;
  }

  Future<GoogleSignInAccount?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    _account = account;
    _api = drive.DriveApi(_AuthedClient(account));
    // Drive ids are per account; a folder id cached for the previous account
    // would resolve to nothing.
    _folderId = null;
    _movedLegacyBackups = false;
    return account;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    _api = null;
    _folderId = null;
    _movedLegacyBackups = false;
  }

  drive.DriveApi get _requireApi {
    final api = _api;
    if (api == null) throw StateError('Google Drive is not signed in');
    return api;
  }

  /// The backups users can restore: everything this app created, wherever it
  /// sits. Finding them by name keeps backups written to the old layout (the
  /// Drive root) restorable too.
  Future<List<drive.File>> listBackups() async {
    final res = await _requireApi.files.list(
      // Folders match "contains 'yomou'" as well, and offering one for
      // restore would fail on download.
      q: "name contains 'yomou' "
          "and mimeType != '$folderMimeType' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id,name,modifiedTime,size)',
    );
    return res.files ?? const <drive.File>[];
  }

  /// Uploads into the `Yomou` folder, creating it on first use.
  Future<drive.File> uploadBackup({
    required Uint8List bytes,
    required String name,
  }) async {
    final folderId = await ensureFolder();
    await _moveLegacyBackups(folderId);
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/zip',
    );
    final file = drive.File()
      ..name = name
      ..parents = [folderId];
    return _requireApi.files.create(file, uploadMedia: media);
  }

  Future<Uint8List> downloadBackup(String id) async {
    final media = await _requireApi.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return Uint8List.fromList(bytes);
  }

  Future<void> deleteBackup(String id) => _requireApi.files.delete(id);

  /// Deletes the oldest backups so at most [keep] remain in the folder.
  ///
  /// Only the folder is counted: files the user exported to their own device
  /// are not ours to delete, and legacy root backups are left to the one-off
  /// move rather than being silently removed.
  Future<void> pruneBackups({required int keep}) async {
    if (keep <= 0) return;
    final folderId = _folderId ?? await _findFolderId();
    if (folderId == null) return;
    final res = await _requireApi.files.list(
      q: "'$folderId' in parents and mimeType != '$folderMimeType' "
          'and trashed = false',
      spaces: 'drive',
      orderBy: 'modifiedTime desc',
      $fields: 'files(id)',
    );
    final files = res.files ?? const <drive.File>[];
    for (final file in files.skip(keep)) {
      final id = file.id;
      if (id == null) continue;
      await _requireApi.files.delete(id);
    }
  }

  /// Returns the id of the folder backups live in, creating it if needed.
  Future<String> ensureFolder() async {
    final cached = _folderId;
    if (cached != null) return cached;

    var id = await _findFolderId();
    id ??= (await _requireApi.files.create(
      drive.File()
        ..name = folderName
        ..mimeType = folderMimeType,
      $fields: 'id',
    ))
        .id;
    if (id == null) {
      throw StateError('Drive did not return an id for the backup folder');
    }
    _folderId = id;
    return id;
  }

  Future<String?> _findFolderId() async {
    // drive.file only exposes files this app created, so a plain list is
    // enough to find a folder from an earlier session.
    final res = await _requireApi.files.list(
      q: "name = '$folderName' "
          "and mimeType = '$folderMimeType' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    final matches = res.files ?? const <drive.File>[];
    return matches.isEmpty ? null : matches.first.id;
  }

  Future<void> _moveLegacyBackups(String folderId) async {
    if (_movedLegacyBackups) return;
    _movedLegacyBackups = true;
    try {
      final res = await _requireApi.files.list(
        q: "name contains 'yomou' and mimeType != '$folderMimeType' "
            "and 'root' in parents and trashed = false",
        spaces: 'drive',
        $fields: 'files(id)',
      );
      for (final file in res.files ?? const <drive.File>[]) {
        final id = file.id;
        if (id == null) continue;
        await _requireApi.files.update(
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
