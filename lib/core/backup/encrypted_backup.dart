import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// Encrypted, password-protected Yomou backup.
///
/// The payload is the same data the plain Tachiyomi export carries (favorites,
/// bookmarks, reading progress), serialised as JSON and sealed with Fernet
/// (AES-128-CBC + HMAC-SHA256) under a key derived from the user's password
/// via PBKDF2-HMAC-SHA256. A random 16-byte salt and a fresh Fernet IV make
/// every export unique even for the same password and data.
///
/// Format (bytes):
///   magic "YOMOUENC1" (9) | version (1) | salt (16) | fernet token (rest)
class EncryptedBackupCodec {
  EncryptedBackupCodec._();

  static const _magic = 'YOMOUENC1';
  static const _version = 1;
  static const _saltLen = 16;
  static const _iterations = 100000;

  /// Builds the encrypted bytes from Yomou database rows.
  static Uint8List export({
    required List<Map<String, dynamic>> favorites,
    required List<Map<String, dynamic>> bookmarks,
    required List<Map<String, dynamic>> readingProgress,
    required String password,
  }) {
    final payload = jsonEncode({
      'favorites': favorites,
      'bookmarks': bookmarks,
      'readingProgress': readingProgress,
      'exportedAt': DateTime.now().millisecondsSinceEpoch,
    });

    final salt = _secureRandom(_saltLen);
    final key = _deriveKey(password, salt);
    final fernet = Fernet(Key(key));
    final token = fernet.encrypt(Uint8List.fromList(utf8.encode(payload)));

    final out = BytesBuilder();
    out.add(utf8.encode(_magic));
    out.addByte(_version);
    out.add(salt);
    out.add(token.bytes);
    return out.toBytes();
  }

  /// Decrypts and parses an encrypted backup.
  /// Throws [FormatException] on malformed input or a wrong password.
  static EncryptedBackupImportResult import(Uint8List bytes, String password) {
    if (bytes.length < _magic.length + 1 + _saltLen + 1) {
      throw const FormatException('Not a Yomou encrypted backup');
    }
    final magic = utf8.decode(bytes.sublist(0, _magic.length));
    if (magic != _magic) {
      throw const FormatException('Not a Yomou encrypted backup');
    }
    final version = bytes[_magic.length];
    if (version != _version) {
      throw FormatException('Unsupported backup version $version');
    }
    final salt = bytes.sublist(_magic.length + 1, _magic.length + 1 + _saltLen);
    final token = bytes.sublist(_magic.length + 1 + _saltLen);

    final key = _deriveKey(password, salt);
    final fernet = Fernet(Key(key));
    Uint8List plain;
    try {
      plain = fernet.decrypt(Encrypted(token));
    } catch (_) {
      throw const FormatException('Wrong password or corrupt backup');
    }

    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return EncryptedBackupImportResult(
      favorites: (json['favorites'] as List?)?.cast<Map<String, dynamic>>() ??
          const [],
      bookmarks: (json['bookmarks'] as List?)?.cast<Map<String, dynamic>>() ??
          const [],
      readingProgress:
          (json['readingProgress'] as List?)?.cast<Map<String, dynamic>>() ??
              const [],
    );
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    // PBKDF2-HMAC-SHA256, 32 bytes.
    const length = 32;
    final hmac = Hmac(sha256, utf8.encode(password));
    final blocks = (length + 31) ~/ 32;
    final out = Uint8List(length);
    for (var i = 1; i <= blocks; i++) {
      final blockInput = Uint8List(salt.length + 4);
      blockInput.setRange(0, salt.length, salt);
      blockInput[salt.length] = (i >> 24) & 0xff;
      blockInput[salt.length + 1] = (i >> 16) & 0xff;
      blockInput[salt.length + 2] = (i >> 8) & 0xff;
      blockInput[salt.length + 3] = i & 0xff;
      var u = Uint8List.fromList(hmac.convert(blockInput).bytes);
      final t = Uint8List.fromList(u);
      for (var c = 2; c <= _iterations; c++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      final offset = (i - 1) * 32;
      for (var j = 0; j < 32 && offset + j < length; j++) {
        out[offset + j] = t[j];
      }
    }
    return out;
  }

  static Uint8List _secureRandom(int length) {
    return SecureRandom(length).bytes;
  }
}

class EncryptedBackupImportResult {
  const EncryptedBackupImportResult({
    required this.favorites,
    required this.bookmarks,
    required this.readingProgress,
  });

  final List<Map<String, dynamic>> favorites;
  final List<Map<String, dynamic>> bookmarks;
  final List<Map<String, dynamic>> readingProgress;
}
