import 'dart:convert';
import 'dart:typed_data';

/// Port of Kotatsu's `MangaFireParser.VrfGenerator` (kotatsu-parsers, GPL-3.0).
///
/// MangaFire's internal `/ajax/*` endpoints reject requests whose URL lacks a
/// signed `vrf` query parameter. The token is produced by repeatedly mangling
/// the plaintext through a fixed pipeline of RC4 ciphersteps, byte transforms
/// keyed by per-step schedules, and prefix key injection, then Base64URL-
/// encoded. The whole scheme and its keys are static (no server nonce), so the
/// exact port reproduces valid tokens.
abstract final class MfVrf {
  static Uint8List _atob(String data) => base64.decode(data);

  static String _btoa(List<int> data) =>
      base64Url.encode(data).replaceAll('=', '');

  static Uint8List _rc4(Uint8List key, Uint8List input) {
    final s = List<int>.generate(256, (i) => i);
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + s[i] + key[i % key.length]) & 0xFF;
      final t = s[i];
      s[i] = s[j];
      s[j] = t;
    }
    final out = Uint8List(input.length);
    var i = 0;
    j = 0;
    for (var y = 0; y < input.length; y++) {
      i = (i + 1) & 0xFF;
      j = (j + s[i]) & 0xFF;
      final t = s[i];
      s[i] = s[j];
      s[j] = t;
      out[y] = input[y] ^ s[(s[i] + s[j]) & 0xFF];
    }
    return out;
  }

  static Uint8List _transform(
    Uint8List input,
    Uint8List initSeedBytes,
    Uint8List prefixKeyBytes,
    int prefixLen,
    List<int Function(int)> schedule,
  ) {
    final out = Uint8List(input.length + prefixLen);
    var idx = 0;
    for (var i = 0; i < input.length; i++) {
      if (i < prefixLen) out[idx++] = prefixKeyBytes[i];
      final t = (input[i] ^ initSeedBytes[i % 32]) & 0xFF;
      out[idx++] = schedule[i % 10](t) & 0xFF;
    }
    return out;
  }

  static final List<int Function(int)> _scheduleC = [
    (c) => (c - 48 + 256) & 0xFF,
    (c) => (c - 19 + 256) & 0xFF,
    (c) => c ^ 241,
    (c) => (c - 19 + 256) & 0xFF,
    (c) => (c + 223) & 0xFF,
    (c) => (c - 19 + 256) & 0xFF,
    (c) => (c - 170 + 256) & 0xFF,
    (c) => (c - 19 + 256) & 0xFF,
    (c) => (c - 48 + 256) & 0xFF,
    (c) => c ^ 8,
  ];

  static final List<int Function(int)> _scheduleY = [
    (c) => ((c << 4) | (c >> 4)) & 0xFF,
    (c) => (c + 223) & 0xFF,
    (c) => ((c << 4) | (c >> 4)) & 0xFF,
    (c) => c ^ 163,
    (c) => (c - 48 + 256) & 0xFF,
    (c) => (c + 82) & 0xFF,
    (c) => (c + 223) & 0xFF,
    (c) => (c - 48 + 256) & 0xFF,
    (c) => c ^ 83,
    (c) => ((c << 4) | (c >> 4)) & 0xFF,
  ];

  static final List<int Function(int)> _scheduleB = [
    (c) => (c - 19 + 256) & 0xFF,
    (c) => (c + 82) & 0xFF,
    (c) => (c - 48 + 256) & 0xFF,
    (c) => (c - 170 + 256) & 0xFF,
    (c) => ((c << 4) | (c >> 4)) & 0xFF,
    (c) => (c - 48 + 256) & 0xFF,
    (c) => (c - 170 + 256) & 0xFF,
    (c) => c ^ 8,
    (c) => (c + 82) & 0xFF,
    (c) => c ^ 163,
  ];

  static final List<int Function(int)> _scheduleJ = [
    (c) => (c + 223) & 0xFF,
    (c) => ((c << 4) | (c >> 4)) & 0xFF,
    (c) => (c + 223) & 0xFF,
    (c) => c ^ 83,
    (c) => (c - 19 + 256) & 0xFF,
    (c) => (c + 223) & 0xFF,
    (c) => (c - 170 + 256) & 0xFF,
    (c) => (c + 223) & 0xFF,
    (c) => (c - 170 + 256) & 0xFF,
    (c) => c ^ 83,
  ];

  static final List<int Function(int)> _scheduleE = [
    (c) => (c + 82) & 0xFF,
    (c) => c ^ 83,
    (c) => c ^ 163,
    (c) => (c + 82) & 0xFF,
    (c) => (c - 170 + 256) & 0xFF,
    (c) => c ^ 8,
    (c) => c ^ 241,
    (c) => (c + 82) & 0xFF,
    (c) => (c + 176) & 0xFF,
    (c) => ((c << 4) | (c >> 4)) & 0xFF,
  ];

  static const Map<String, String> _rc4Keys = {
    'l': 'u8cBwTi1CM4XE3BkwG5Ble3AxWgnhKiXD9Cr279yNW0=',
    'g': 't00NOJ/Fl3wZtez1xU6/YvcWDoXzjrDHJLL2r/IWgcY=',
    'B': 'S7I+968ZY4Fo3sLVNH/ExCNq7gjuOHjSRgSqh6SsPJc=',
    'm': '7D4Q8i8dApRj6UWxXbIBEa1UqvjI+8W0UvPH9talJK8=',
    'F': '0JsmfWZA1kwZeWLk5gfV5g41lwLL72wHbam5ZPfnOVE=',
  };

  static const Map<String, String> _seeds32 = {
    'A': 'pGjzSCtS4izckNAOhrY5unJnO2E1VbrU+tXRYG24vTo=',
    'V': 'dFcKX9Qpu7mt/AD6mb1QF4w+KqHTKmdiqp7penubAKI=',
    'N': 'owp1QIY/kBiRWrRn9TLN2CdZsLeejzHhfJwdiQMjg3w=',
    'P': 'H1XbRvXOvZAhyyPaO68vgIUgdAHn68Y6mrwkpIpEue8=',
    'k': '2Nmobf/mpQ7+Dxq1/olPSDj3xV8PZkPbKaucJvVckL0=',
  };

  static const Map<String, String> _prefixKeys = {
    'O': 'Rowe+rg/0g==',
    'v': '8cULcnOMJVY8AA==',
    'L': 'n2+Og2Gth8Hh',
    'p': 'aRpvzH+yoA==',
    'W': 'ZB4oBi0=',
  };

  /// Generates the `vrf` query parameter for a given plaintext input.
  static String generate(String input) {
    var bytes = Uint8List.fromList(utf8.encode(input));
    bytes = _rc4(_atob(_rc4Keys['l']!), bytes);
    bytes = _transform(
        bytes, _atob(_seeds32['A']!), _atob(_prefixKeys['O']!), 7, _scheduleC);
    bytes = _rc4(_atob(_rc4Keys['g']!), bytes);
    bytes = _transform(
        bytes, _atob(_seeds32['V']!), _atob(_prefixKeys['v']!), 10, _scheduleY);
    bytes = _rc4(_atob(_rc4Keys['B']!), bytes);
    bytes = _transform(
        bytes, _atob(_seeds32['N']!), _atob(_prefixKeys['L']!), 9, _scheduleB);
    bytes = _rc4(_atob(_rc4Keys['m']!), bytes);
    bytes = _transform(
        bytes, _atob(_seeds32['P']!), _atob(_prefixKeys['p']!), 7, _scheduleJ);
    bytes = _rc4(_atob(_rc4Keys['F']!), bytes);
    bytes = _transform(
        bytes, _atob(_seeds32['k']!), _atob(_prefixKeys['W']!), 5, _scheduleE);
    return _btoa(bytes);
  }
}