import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/backup/saf_directory_picker.dart';
import 'package:yomou/core/storage/storage_stats.dart';

/// A user-added download location picked through the storage-access framework.
/// [uri] is the persistable tree URI; [title] is what the UI shows.
class CustomDownloadDir {
  const CustomDownloadDir({required this.uri, required this.title});

  final String uri;
  final String title;

  Map<String, String> toJson() => {'uri': uri, 'title': title};

  static CustomDownloadDir fromJson(Map<String, dynamic> json) =>
      CustomDownloadDir(
        uri: json['uri'] as String? ?? '',
        title: json['title'] as String? ?? '',
      );
}

/// Downloads-folder ids, matching the "Downloads folder" picker.
const kFolderChapters = 'chapters';
const kFolderPublic = 'public';
const kFolderDocuments = 'documents';
const kFolderCustomPrefix = 'custom:';

/// Download format ids ("Preferred download format" picker).
const kFormatAuto = 'auto';
const kFormatSingleCbz = 'cbz';
const kFormatMultipleCbz = 'cbzs';

/// Cellular-network policy ids ("Downloading over cellular network" picker).
const kNetworkAllow = 'allow';
const kNetworkAsk = 'ask';
const kNetworkDeny = 'deny';

/// Settings surfaced in Settings > Downloads. Values are persisted so the
/// module keeps its state across launches; the fields that can drive real
/// behaviour (the chosen download folder and page-save directory) are honored
/// by [chaptersRoot] and the reader's page-save flow.
class DownloadSettings {
  const DownloadSettings({
    required this.downloadsFolder,
    required this.preferredFormat,
    required this.cellularNetwork,
    required this.defaultPageSaveDir,
    required this.askDestinationEveryTime,
    required this.customDirs,
  });

  factory DownloadSettings.defaults() => const DownloadSettings(
        downloadsFolder: kFolderChapters,
        preferredFormat: kFormatAuto,
        cellularNetwork: kNetworkAsk,
        // No page-save directory chosen yet: the row shows "Not set" and the
        // reader falls back to the shared downloads folder until the user
        // picks one through the system folder picker.
        defaultPageSaveDir: '',
        askDestinationEveryTime: false,
        customDirs: [],
      );

  /// Where chapter downloads are stored: a [kFolder*] id, or
  /// `$kFolderCustomPrefix<tree-uri>` for a folder picked by the user.
  final String downloadsFolder;

  final String preferredFormat;
  final String cellularNetwork;

  /// Where the reader saves individual pages: [kFolderPublic],
  /// [kFolderDocuments] or a custom tree URI.
  final String defaultPageSaveDir;

  /// When true, the reader asks for the destination before each download.
  final bool askDestinationEveryTime;

  /// Additional locations the user has added via the directory picker.
  final List<CustomDownloadDir> customDirs;

  bool get usesCustomFolder =>
      downloadsFolder.startsWith(kFolderCustomPrefix);

  DownloadSettings copyWith({
    String? downloadsFolder,
    String? preferredFormat,
    String? cellularNetwork,
    String? defaultPageSaveDir,
    bool? askDestinationEveryTime,
    List<CustomDownloadDir>? customDirs,
  }) => DownloadSettings(
        downloadsFolder: downloadsFolder ?? this.downloadsFolder,
        preferredFormat: preferredFormat ?? this.preferredFormat,
        cellularNetwork: cellularNetwork ?? this.cellularNetwork,
        defaultPageSaveDir: defaultPageSaveDir ?? this.defaultPageSaveDir,
        askDestinationEveryTime:
            askDestinationEveryTime ?? this.askDestinationEveryTime,
        customDirs: customDirs ?? this.customDirs,
      );

  /// The chapter-download root the settings currently point at, mirroring the
  /// historical behaviour when the preference is the default ('chapters' =
  /// the app's private support directory). Custom SAF tree URIs are not real
  /// file-system paths and fall back to the private root.
  static Future<Directory> chaptersRoot() async {
    final p_ = await SharedPreferences.getInstance();
    final folder = p_.getString(_DownloadSettingsPersistence._kFolder) ??
        kFolderChapters;
    try {
      if (folder == kFolderPublic) {
        final public = await getDownloadsDirectory();
        if (public != null) {
          return Directory(p.join(public.path, 'chapters'));
        }
      } else if (folder == kFolderDocuments) {
        final docs = await getApplicationDocumentsDirectory();
        return Directory(p.join(docs.path, 'chapters'));
      }
    } catch (_) {
      // Storage can be unavailable mid-way; private root is the safe fallback.
    }
    return Directory(
      p.join((await getApplicationSupportDirectory()).path, 'chapters'),
    );
  }
}

/// Resolves a location id to a real file-system path for display. `custom:`
/// ids hold a SAF tree URI, which is resolved to its path on the native side;
/// the built-in roots come straight from path_provider. Returns null when the
/// location can't be resolved (e.g. an unmounted SD card).
Future<String?> resolveDownloadLocationPath(String id) async {
  try {
    if (id == kFolderChapters) {
      return (await DownloadSettings.chaptersRoot()).path;
    }
    if (id == kFolderPublic) {
      return await getPublicDownloadsPath();
    }
    if (id == kFolderDocuments) {
      return (await getApplicationDocumentsDirectory()).path;
    }
    if (id.startsWith(kFolderCustomPrefix)) {
      return await resolveTreeUri(id.substring(kFolderCustomPrefix.length));
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Whether Yomou can actually create files in [path].
///
/// Probes with a real write instead of trusting a permission bit, so a folder
/// on a locked SD card or one outside our storage grant is reported honestly
/// (the directories screen surfaces this as a warning on the card).
Future<bool> isDirWritable(String path) async {
  if (path.isEmpty) return false;
  final probe = File(p.join(path, '.yomou-write-probe'));
  try {
    await probe.writeAsString('');
    await probe.delete();
    return true;
  } catch (_) {
    return false;
  }
}

/// Drops a `.nomedia` file in the folder behind [id] so downloaded chapters and
/// saved pages don't show up in the gallery's media scanner. Best effort: the
/// folder may be read-only, in which case there is nothing to do.
Future<void> markDirAsNoMedia(String id) async {
  final path = await resolveDownloadLocationPath(id);
  if (path == null || path.isEmpty) return;
  try {
    final file = File(p.join(path, '.nomedia'));
    if (!await file.exists()) {
      await file.writeAsString('');
    }
  } catch (_) {
    // Read-only location — the download simply won't be indexed.
  }
}

/// Reads the persisted download settings without a [Ref] — used by the
/// background isolate, which has no Riverpod container.
Future<DownloadSettings> loadDownloadSettings() =>
    _DownloadSettingsPersistence.load();

class _DownloadSettingsPersistence {
  static const _prefix = 'dl.';
  static const _kFolder = '${_prefix}folder';
  static const _kFormat = '${_prefix}format';
  static const _kNetwork = '${_prefix}network';
  static const _kSaveDir = '${_prefix}saveDir';
  static const _kAskDir = '${_prefix}askDir';
  static const _kCustomDirs = '${_prefix}customDirs';

  static Future<DownloadSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final customRaw = p.getString(_kCustomDirs) ?? '[]';
    List<CustomDownloadDir> custom = [];
    try {
      custom = (jsonDecode(customRaw) as List)
          .map((e) => CustomDownloadDir.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      custom = [];
    }
    return DownloadSettings(
      downloadsFolder: p.getString(_kFolder) ?? kFolderChapters,
      preferredFormat: p.getString(_kFormat) ?? kFormatAuto,
      cellularNetwork: p.getString(_kNetwork) ?? kNetworkAsk,
      defaultPageSaveDir: p.getString(_kSaveDir) ?? '',
      askDestinationEveryTime: p.getBool(_kAskDir) ?? false,
      customDirs: custom,
    );
  }

  static Future<void> save(DownloadSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kFolder, s.downloadsFolder);
    await p.setString(_kFormat, s.preferredFormat);
    await p.setString(_kNetwork, s.cellularNetwork);
    await p.setString(_kSaveDir, s.defaultPageSaveDir);
    await p.setBool(_kAskDir, s.askDestinationEveryTime);
    await p.setString(
      _kCustomDirs,
      jsonEncode(s.customDirs.map((d) => d.toJson()).toList()),
    );
  }
}

class DownloadSettingsNotifier extends StateNotifier<DownloadSettings> {
  DownloadSettingsNotifier() : super(DownloadSettings.defaults()) {
    _load();
  }

  Future<void> _load() async {
    state = await _DownloadSettingsPersistence.load();
  }

  Future<void> setDownloadsFolder(String folder) async {
    state = state.copyWith(downloadsFolder: folder);
    await _persist();
  }

  Future<void> setPreferredFormat(String format) async {
    state = state.copyWith(preferredFormat: format);
    await _persist();
  }

  Future<void> setCellularNetwork(String policy) async {
    state = state.copyWith(cellularNetwork: policy);
    await _persist();
  }

  Future<void> setDefaultPageSaveDir(String folder) async {
    state = state.copyWith(defaultPageSaveDir: folder);
    await _persist();
  }

  Future<void> setAskDestinationEveryTime(bool ask) async {
    state = state.copyWith(askDestinationEveryTime: ask);
    await _persist();
  }

  Future<void> addCustomDir(String uri, String title) async {
    await markDirAsNoMedia('$kFolderCustomPrefix$uri');
    final dirs = [...state.customDirs];
    dirs.removeWhere((d) => d.uri == uri);
    dirs.add(CustomDownloadDir(uri: uri, title: title));
    state = state.copyWith(customDirs: dirs);
    await _persist();
  }

  Future<void> removeCustomDir(String uri) async {
    state = state.copyWith(
      customDirs: state.customDirs.where((d) => d.uri != uri).toList(),
    );
    await _persist();
  }

  Future<void> _persist() async {
    await _DownloadSettingsPersistence.save(state);
  }
}

final downloadSettingsProvider =
    StateNotifierProvider<DownloadSettingsNotifier, DownloadSettings>(
        (ref) => DownloadSettingsNotifier());