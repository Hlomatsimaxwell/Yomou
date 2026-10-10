import 'dart:convert';
import 'dart:typed_data';

/// Decodes the encrypted page-image list Mangago embeds in a chapter page.
///
/// Every reader page carries a line like
/// `var imgsrcs = '<base64>';`. The payload is the comma-joined list of the
/// chapter's page URLs, AES-128-CBC encrypted with a site-pinned key and IV
/// (both public, hard-coded by the reader), zero-padded, then Base64. The
/// reader decrypts it client-side: Chrome's DOM for the same page shows the
/// resulting URLs in the `<img id="pageN">` tags, and this decoder produces
/// exactly those URLs (verified against the live site for two chapter pages,
/// including the full 61-entry list).
///
/// Older copies of the reader additionally removed 4 characters at fixed
/// offsets and ran a per-character shuffle (`dorder`) over the plaintext
/// before splitting. The current site no longer does either (its payloads
/// decrypt straight to clean URLs), so that legacy pass is kept only as a
/// fallback for payloads that still carry it: both candidates are decoded and
/// the one that yields the most `http(s)` URLs wins.
abstract final class MangagoCipher {
  static const String _keyHex = 'e11adc3949ba59abbe56e057f20f883e';
  static const String _ivHex = '1234567890abcdef1234567890abcdef';

  /// Positions (0-based) of the four characters the legacy reader removed
  /// from the decrypted string. Removed highest-first so earlier removals do
  /// not shift the later indexes.
  static const List<int> _legacyRemove = [39, 31, 23, 19];

  /// Character codes of the legacy `dorder` key `"abcd"` minus `'0'`:
  /// 'd'=52, 'c'=51, 'b'=50, 'a'=49, applied in that order (j = 3..0).
  static const List<int> _legacyOffsets = [52, 51, 50, 49];

  /// Decrypts [payload] (the Base64 value of `var imgsrcs = '...'`) into the
  /// ordered page-URL list. Returns an empty list when nothing usable decodes.
  static List<String> decodeImgsrcs(String payload) {
    final cipher = base64.decode(payload);
    final plain = _aesDecryptCbc(cipher, _hexBytes(_keyHex), _hexBytes(_ivHex));
    final text = _stripTrailingZeros(latin1.decode(plain));

    final plainUrls = _split(text);
    final legacyUrls = _split(dorder(_removePositions(text), _legacyOffsets));
    final best = _preferUrls(legacyUrls, plainUrls) ? legacyUrls : plainUrls;
    return [for (final u in best) _fixFilenameZ(u)];
  }

  static bool _preferUrls(List<String> a, List<String> b) {
    int score(List<String> urls) => urls
        .where((u) => u.startsWith('http://') || u.startsWith('https://'))
        .length;
    final sa = score(a);
    final sb = score(b);
    if (sa != sb) return sa > sb;
    // Tie on well-formed URLs: keep the longer list, so a chapter whose
    // payload split into more fragments does not get truncated.
    return a.length > b.length;
  }

  static List<String> _split(String text) =>
      text.split(',').where((e) => e.isNotEmpty).toList();

  /// Strips the zero-padding the reader left behind (it removes every
  /// trailing `\x00` byte, not just up to one block).
  static String _stripTrailingZeros(String s) {
    var end = s.length;
    while (end > 0 && s.codeUnitAt(end - 1) == 0) {
      end--;
    }
    return s.substring(0, end);
  }

  static String _removePositions(String s) {
    final chars = s.split('');
    for (final p in _legacyRemove) {
      if (p >= 0 && p < chars.length) chars.removeAt(p);
    }
    return chars.join();
  }

  /// The legacy reader's `dorder($str, $key)` shuffle: for j = 3 down to 0,
  /// walk i from the end back to offset, swapping positions i and i - offset
  /// whenever i is odd. Strings are swapped via a character list because the
  /// payloads can run several kilobytes.
  static String dorder(String str, List<int> offsets) {
    final chars = str.split('');
    final n = chars.length;
    for (final off in offsets) {
      for (var i = n - 1; i - off >= 0; i--) {
        if (i % 2 != 0) {
          final tmp = chars[i - off];
          chars[i - off] = chars[i];
          chars[i] = tmp;
        }
      }
    }
    return chars.join();
  }

  /// Rare filename quirk: when the filename's 6th character (index 6) is 'z'
  /// the reader drops it (`fname.substring(0,6) + fname.substring(7)`).
  static String _fixFilenameZ(String url) {
    final slash = url.lastIndexOf('/');
    if (slash < 0) return url;
    final fname = url.substring(slash + 1);
    if (fname.length > 6 && fname.codeUnitAt(6) == 0x7A) {
      return '${url.substring(0, slash + 1)}'
          '${fname.substring(0, 6)}${fname.substring(7)}';
    }
    return url;
  }

  static List<int> _hexBytes(String hex) {
    final out = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  // ---- AES-128-CBC decrypt, self-contained (mirrors the repo's hand-rolled
  // RC4 in mangafire_vrf.dart rather than pulling a crypto dependency). ----

  static Uint8List _aesDecryptCbc(
    List<int> ciphertext,
    List<int> key,
    List<int> iv,
  ) {
    final rk = _expandKey(key);
    final pt = Uint8List(ciphertext.length);
    var prev = Uint8List.fromList(iv);
    for (var off = 0; off < ciphertext.length; off += 16) {
      final block = Uint8List.sublistView(
        Uint8List.fromList(ciphertext),
        off,
        off + 16,
      );
      final dec = _decryptBlock(block, rk);
      for (var i = 0; i < 16; i++) {
        pt[off + i] = dec[i] ^ prev[i];
      }
      prev = block;
    }
    return pt;
  }

  static Uint8List _decryptBlock(Uint8List block, Uint8List roundKeys) {
    final s = Uint8List.fromList(block);
    _addRoundKey(s, roundKeys, 160); // round 10
    for (var round = 9; round >= 1; round--) {
      _invShiftRows(s);
      _invSubBytes(s);
      _addRoundKey(s, roundKeys, round * 16);
      _invMixColumns(s);
    }
    _invShiftRows(s);
    _invSubBytes(s);
    _addRoundKey(s, roundKeys, 0);
    return s;
  }

  static void _addRoundKey(Uint8List s, Uint8List rk, int off) {
    for (var i = 0; i < 16; i++) {
      s[i] ^= rk[off + i];
    }
  }

  // Rows shift *right* by their index (column c takes the byte that was at
  // (c + 4 - r) mod 4); the loop below writes it as "c + n" with n = 4 - r.
  static void _invShiftRows(Uint8List s) {
    void rot(int r, int n) {
      final row = List<int>.filled(4, 0);
      for (var c = 0; c < 4; c++) {
        row[c] = s[r + 4 * c];
      }
      for (var c = 0; c < 4; c++) {
        s[r + 4 * c] = row[(c + n) % 4];
      }
    }

    rot(1, 3);
    rot(2, 2);
    rot(3, 1);
  }

  static void _invSubBytes(Uint8List s) {
    for (var i = 0; i < 16; i++) {
      s[i] = _invSbox[s[i]];
    }
  }

  static void _invMixColumns(Uint8List s) {
    for (var c = 0; c < 4; c++) {
      final a0 = s[0 + 4 * c];
      final a1 = s[1 + 4 * c];
      final a2 = s[2 + 4 * c];
      final a3 = s[3 + 4 * c];
      s[0 + 4 * c] = _gmul(a0, 14) ^ _gmul(a1, 11) ^
          _gmul(a2, 13) ^ _gmul(a3, 9);
      s[1 + 4 * c] = _gmul(a0, 9) ^ _gmul(a1, 14) ^
          _gmul(a2, 11) ^ _gmul(a3, 13);
      s[2 + 4 * c] = _gmul(a0, 13) ^ _gmul(a1, 9) ^
          _gmul(a2, 14) ^ _gmul(a3, 11);
      s[3 + 4 * c] = _gmul(a0, 11) ^ _gmul(a1, 13) ^
          _gmul(a2, 9) ^ _gmul(a3, 14);
    }
  }

  static Uint8List _expandKey(List<int> key) {
    final w = List<int>.filled(44 * 4, 0);
    for (var i = 0; i < 16; i++) {
      w[i] = key[i];
    }
    for (var i = 4; i < 44; i++) {
      var t0 = w[(i - 1) * 4];
      var t1 = w[(i - 1) * 4 + 1];
      var t2 = w[(i - 1) * 4 + 2];
      var t3 = w[(i - 1) * 4 + 3];
      if (i % 4 == 0) {
        final tmp = t0;
        t0 = _sbox[t1] ^ _rcon[i ~/ 4 - 1];
        t1 = _sbox[t2];
        t2 = _sbox[t3];
        t3 = _sbox[tmp];
      }
      final p = (i - 4) * 4;
      w[i * 4] = w[p] ^ t0;
      w[i * 4 + 1] = w[p + 1] ^ t1;
      w[i * 4 + 2] = w[p + 2] ^ t2;
      w[i * 4 + 3] = w[p + 3] ^ t3;
    }
    return Uint8List.fromList(w);
  }

  static const List<int> _rcon = [
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36,
  ];

  static int _xtime(int a) =>
      (a & 0x80) != 0 ? ((a << 1) & 0x1FF) ^ 0x11B : a << 1;

  /// Multiplication in GF(2^8) via exponentiation tables built on the
  /// primitive element 0x03. (A table built by doubling 0x02 is not
  /// primitive for the AES polynomial -- see [_buildLogExp].)
  static int _gmul(int a, int b) {
    if (a == 0 || b == 0) return 0;
    return _gfExp[(_gfLog[a] + _gfLog[b]) % 255];
  }

  static List<int> _buildLogExp() {
    final log = List<int>.filled(256, 0);
    final exp = List<int>.filled(256, 0);
    var x = 1;
    for (var i = 0; i < 255; i++) {
      exp[i] = x;
      log[x] = i;
      x = _xtime(x) ^ x; // multiply by 0x03 (x being 3 is primitive)
    }
    exp[255] = 1; // wrap: exp[0] already holds 1
    return [...log, ...exp];
  }

  static final List<int> _gfTables = _buildLogExp();
  static final List<int> _gfLog = _gfTables.sublist(0, 256);
  static final List<int> _gfExp = _gfTables.sublist(256, 512);

  static List<int> _buildSbox() {
    final s = List<int>.filled(256, 0);
    for (var i = 0; i < 256; i++) {
      // Multiplicative inverse in GF(2^8) (0 maps to itself).
      var b = i == 0 ? 0 : _gfExp[(255 - _gfLog[i]) % 255];
      var v = b;
      for (var r = 1; r < 5; r++) {
        v ^= ((b << r) | (b >> (8 - r))) & 0xFF;
      }
      s[i] = v ^ 0x63; // affine transform
    }
    return s;
  }

  static final List<int> _sbox = _buildSbox();
  static final List<int> _invSbox =
      List<int>.generate(256, (i) => _sbox.indexOf(i));
}