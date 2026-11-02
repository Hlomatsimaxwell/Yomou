import 'dart:convert';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:yomou/core/backup/backup_restore.dart';
import 'package:yomou/core/backup/kotatsu_backup.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// Cloud backup via WebDAV (self-hosted: Nextcloud, own server, ...).
///
/// Uses HTTP basic auth against a user-provided WebDAV URL. Works on
/// Android and iOS alike since it is plain HTTP. Google Drive support can
/// be added later on top of the same upload/download helpers.
class CloudBackupScreen extends ConsumerStatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  ConsumerState<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends ConsumerState<CloudBackupScreen> {
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  bool _busy = false;
  String? _status;
  List<_RemoteFile> _remoteFiles = const [];

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  String get _base => _urlController.text.trim().replaceAll(RegExp(r'/+$'), '');

  Map<String, String> get _authHeaders => {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('${_userController.text}:${_passController.text}'))}',
      };

  Future<void> _testConnection() async {
    if (_base.isEmpty) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final res = await http.head(Uri.parse(_base), headers: _authHeaders);
      if (!mounted) return;
      setState(() {
        _status = res.statusCode >= 200 && res.statusCode < 400
            ? 'Connection OK (${res.statusCode})'
            : 'Connection failed (${res.statusCode})';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Connection error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _listRemote() async {
    if (_base.isEmpty) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final req = http.Request('PROPFIND', Uri.parse('$_base/'));
      req.headers.addAll(_authHeaders);
      req.headers['Depth'] = '1';
      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      if (!mounted) return;
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        // Pull hrefs + last-modified out of the multistatus XML.
        final responses = RegExp(
          r'<d:response>(.*?)</d:response>',
          caseSensitive: false,
          dotAll: true,
        ).allMatches(body);
        final files = <_RemoteFile>[];
        for (final r in responses) {
          final chunk = r.group(1)!;
          final hrefMatch =
              RegExp(r'<d:href>([^<]+)</d:href>', caseSensitive: false)
                  .firstMatch(chunk);
          if (hrefMatch == null) continue;
          final href = hrefMatch.group(1)!;
          if (href.endsWith('/')) continue;
          final name = href.split('/').last;
          if (name.isEmpty) continue;
          DateTime? modified;
          final lmMatch = RegExp(
            r'<d:getlastmodified>([^<]+)</d:getlastmodified>',
            caseSensitive: false,
          ).firstMatch(chunk);
          if (lmMatch != null) {
            try {
              modified = HttpDate.parse(lmMatch.group(1)!.trim());
            } catch (_) {
              modified = null;
            }
          }
          files.add(_RemoteFile(name: name, modified: modified));
        }
        setState(() {
          _remoteFiles = files;
          _status = 'Found ${files.length} remote file(s)';
        });
      } else {
        setState(() => _status = 'List failed (${streamed.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'List error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupNow() async {
    if (_base.isEmpty) return;
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
      final res = await http.put(
        Uri.parse('$_base/$name'),
        headers: _authHeaders,
        body: result.bytes,
      );
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() => _status = 'Uploaded $name');
      } else {
        setState(() => _status = 'Upload failed (${res.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Backup error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(_RemoteFile f) async {
    if (_base.isEmpty) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final res = await http.get(Uri.parse('$_base/${f.name}'), headers: _authHeaders);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        if (!mounted) return;
        setState(() => _status = 'Download failed (${res.statusCode})');
        return;
      }
      if (!mounted) return;
      final parsed = KotatsuBackupCodec.import(res.bodyBytes);
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
      appBar: SettingsAppBar(title: l.cloudBackup, contentMargin: 24),
      body: CappedContentWidth(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          children: [
            Text(
              'WebDAV (Nextcloud, own server, ...). Works on Android and iOS.',
              style: TextStyle(fontSize: 13, color: color.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'WebDAV URL',
                hintText: 'https://cloud.example.com/remote.php/dav/files/user/Yomou',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _busy ? null : _testConnection,
                    child: const Text('Test connection'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _busy ? null : _listRemote,
                    child: const Text('List files'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _backupNow,
              child: const Text('Back up now'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(_status!, style: TextStyle(color: color.onSurfaceVariant)),
            ],
            if (_remoteFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Remote backups',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final f in _remoteFiles)
                ListTile(
                  title: Text(f.name),
                  subtitle: f.modified == null
                      ? null
                      : Text(
                          _formatDate(f.modified!),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RemoteFile {
  const _RemoteFile({required this.name, this.modified});
  final String name;
  final DateTime? modified;
}
