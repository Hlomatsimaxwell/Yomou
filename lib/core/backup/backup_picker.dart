import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// Extensions a restorable backup can carry.
///
/// `.json` is a Yomou backup or a legacy Tachiyomi export, `.tachibk` is a
/// Mihon/Tachiyomi backup, `.gz` is a gzipped Tachiyomi backup, and `.zip` is
/// a Kotatsu backup. The format is sniffed from the contents, never the
/// extension, so all of them are offered.
const backupExtensions = ['json', 'tachibk', 'gz', 'zip'];

/// Picks a backup file, working around iOS's UTI-based filtering.
///
/// `file_picker` resolves [FileType.custom] extensions through UTIs, and any
/// extension Apple does not already know (`tachibk`, `gz`) comes back as a
/// dynamic type that the plugin silently drops. The picker is then left with
/// only `json`, so a `.tachibk` file shows up greyed out and cannot be tapped.
/// There is no extension filter that both contains `.tachibk` and is understood
/// by iOS, so iOS falls back to showing every file; the contents decide the
/// format from there.
Future<FilePickerResult?> pickBackupFile({
  List<String> extensions = backupExtensions,
}) {
  final ios = Platform.isIOS;
  return FilePicker.platform.pickFiles(
    type: ios ? FileType.any : FileType.custom,
    allowedExtensions: ios ? null : extensions,
    withData: true,
  );
}
