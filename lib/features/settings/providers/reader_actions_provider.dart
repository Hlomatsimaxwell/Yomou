import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The reader's screen is a 3x3 grid of independently mappable zones.
const int kZoneRows = 3;
const int kZoneColumns = 3;

/// What a tap or long tap inside a zone does.
const kActNone = 'none';
const kActNextPage = 'nextPage';
const kActPrevPage = 'prevPage';
const kActNextChapter = 'nextChapter';
const kActPrevChapter = 'prevChapter';
const kActToggleUi = 'toggleUi';
const kActShowMenu = 'showMenu';

/// Order the selection sheet lists them in, and the order [kActIds] is walked
/// by Reset. Deliberately the same in both places so the sheet and the reset
/// never disagree about what exists.
const List<String> kActIds = [
  kActNone,
  kActNextPage,
  kActPrevPage,
  kActNextChapter,
  kActPrevChapter,
  kActToggleUi,
  kActShowMenu,
];

/// What every zone starts on. The whole page toggles the UI on a tap and opens
/// the menu on a long tap, which is what the reader has always done; anything
/// else is a change the user has to make on purpose.
const String kActDefaultTap = kActToggleUi;
const String kActDefaultLongTap = kActShowMenu;

/// The two actions a zone can hold: a tap and a long tap.
enum ZoneGesture { tap, longTap }

/// The 18 assignments behind the grid, as one immutable value.
@immutable
class ZoneAssignment {
  const ZoneAssignment._(this._ids);

  /// Flat list of 18 ids, row-major, tap and long tap alternating per cell.
  factory ZoneAssignment.defaults() {
    const tap = kActDefaultTap;
    const longTap = kActDefaultLongTap;
    final ids = <String>[];
    for (var i = 0; i < kZoneRows * kZoneColumns; i++) {
      ids..add(tap)..add(longTap);
    }
    return ZoneAssignment.fromIds(ids);
  }

  /// Reads a persisted `ra.*` list; anything missing falls back to the default,
  /// so a zone added by a later version is not left unmapped.
  factory ZoneAssignment.fromIds(List<String> ids) {
    final resolved = <String>[];
    for (var i = 0; i < kZoneRows * kZoneColumns; i++) {
      for (var g = 0; g < 2; g++) {
        final id = i < ids.length ? ids[i * 2 + g] : null;
        resolved.add(id != null && kActIds.contains(id) ? id : kActDefaultTap);
      }
    }
    return ZoneAssignment._(resolved);
  }

  final List<String> _ids;

  String action(int row, int column, ZoneGesture gesture) {
    final index = (row * kZoneColumns + column) * 2 + gesture.index;
    return _ids[index];
  }

  ZoneAssignment withAction(int row, int column, ZoneGesture gesture, String id) {
    final next = List<String>.of(_ids);
    next[(row * kZoneColumns + column) * 2 + gesture.index] = id;
    return ZoneAssignment._(next);
  }

  /// True when this zone has anything mapped to it, which is what the grid
  /// tints so an empty zone is distinguishable at a glance.
  bool isMapped(int row, int column) =>
      action(row, column, ZoneGesture.tap) != kActNone ||
      action(row, column, ZoneGesture.longTap) != kActNone;

  List<String> get ids => List<String>.unmodifiable(_ids);

  ZoneAssignment cleared() => ZoneAssignment._(
      List<String>.filled(kZoneRows * kZoneColumns * 2, kActNone));

  @override
  bool operator ==(Object other) {
    if (other is! ZoneAssignment) return false;
    if (other._ids.length != _ids.length) return false;
    for (var i = 0; i < _ids.length; i++) {
      if (other._ids[i] != _ids[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_ids);
}

class ReaderActionsNotifier extends StateNotifier<ZoneAssignment> {
  ReaderActionsNotifier() : super(ZoneAssignment.defaults()) {
    _load();
  }

  static const _key = 'ra.zones';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key);
    if (ids == null || ids.length != kZoneRows * kZoneColumns * 2) return;
    state = ZoneAssignment.fromIds(ids);
  }

  Future<void> _save(ZoneAssignment next) async {
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.ids);
  }

  Future<void> setAction(int row, int column, ZoneGesture gesture, String id) =>
      _save(state.withAction(row, column, gesture, id));

  /// "Reset": every zone back to the defaults.
  Future<void> reset() => _save(ZoneAssignment.defaults());

  /// "Disable all": every zone empty, so a stray tap never turns a page.
  Future<void> disableAll() => _save(state.cleared());
}

final readerActionsProvider =
    StateNotifierProvider<ReaderActionsNotifier, ZoneAssignment>(
        (ref) => ReaderActionsNotifier());
