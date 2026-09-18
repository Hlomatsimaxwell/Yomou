import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pinKey = 'security.pin';
const _protectPrefKey = 'appearance.protectApp';

/// Whether the app is currently locked and whether a PIN has been set.
class LockState {
  final bool locked;
  final bool hasPin;

  const LockState({required this.locked, required this.hasPin});
}

/// Hashes the PIN with a static salt so it isn't stored in plaintext. This is
/// a lightweight local deterrent, not a cryptographic key derivation.
String _hashPin(String pin) {
  var h = 0x811c9dc5;
  for (final code in 'yomou:$pin'.codeUnits) {
    h ^= code;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16);
}

/// Manages the optional app PIN lock ("Protect the app").
class AppLockController extends StateNotifier<LockState> {
  AppLockController() : super(const LockState(locked: false, hasPin: false)) {
    _init();
  }

  String? _hash;

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    _hash = p.getString(_pinKey);
    final protect = p.getBool(_protectPrefKey) ?? false;
    state = LockState(locked: _hash != null && protect, hasPin: _hash != null);
  }

  bool verify(String pin) => _hash != null && _hashPin(pin) == _hash;

  bool get hasPin => _hash != null;

  Future<void> setPin(String pin) async {
    _hash = _hashPin(pin);
    final p = await SharedPreferences.getInstance();
    await p.setString(_pinKey, _hash!);
    state = LockState(locked: false, hasPin: true);
  }

  Future<void> removePin() async {
    _hash = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_pinKey);
    state = const LockState(locked: false, hasPin: false);
  }

  void setLocked(bool value) {
    state = LockState(locked: value, hasPin: _hash != null);
  }
}

final appLockProvider = StateNotifierProvider<AppLockController, LockState>(
  (ref) => AppLockController(),
);