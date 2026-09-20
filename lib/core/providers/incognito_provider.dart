import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global incognito flag. When active, user activity (reading history,
/// search terms, favorites, detail-view side effects) is not persisted so
/// nothing done during the session shows up once it's turned back off.
///
/// Kept as a plain top-level value so the database layer (which has no
/// Riverpod access) can check it cheaply; the provider mirrors it for UI.
bool incognitoActive = false;

class IncognitoNotifier extends StateNotifier<bool> {
  static const _key = 'global_incognito';

  IncognitoNotifier() : super(incognitoActive) {
    restore();
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    incognitoActive = prefs.getBool(_key) ?? false;
    state = incognitoActive;
  }

  Future<void> set(bool value) async {
    incognitoActive = value;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final incognitoProvider = StateNotifierProvider<IncognitoNotifier, bool>(
  (_) => IncognitoNotifier(),
);