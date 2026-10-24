import 'dart:convert';

import 'package:html/parser.dart' show parseFragment;

/// Cleans scraped manga text: descriptions, titles, chapter names, tag
/// labels.
///
/// Sources hand us two kinds of damage, and this extension treats both:
///
/// * Mojibake. Several sites serve UTF-8 bytes without a charset header, or
///   mangle them again inside their CMS, and the mis-decoded text shows up
///   as `â€™`-style garbage in summaries and titles. It is repaired by
///   reading the garbled line back as the Windows-1252 byte stream it
///   actually came from and decoding *that* as UTF-8, which recovers every
///   character byte-for-byte -- quotes, dashes and Spanish accents alike --
///   even when the damage was applied more than once. A token table stands
///   in for the lines where the whole-string re-read is impossible, such as
///   one artifact sitting next to a typographic quote the source really
///   meant; those strings bail out of the re-read wholesale and the table
///   carries them the rest of the way.
/// * Mark-up. Descriptions arrive with `<b>` wrappers, `<br>` joins and
///   `&rsquo;`-style entities; running the string through the fragment
///   parser leaves the plain words behind, with paragraph breaks kept.
extension TextSanitizer on String {
  String sanitizeMangaText() {
    var text = this;
    text = _redecodeMisEncodedUtf8(text);
    text = _patchResidualArtefacts(text);
    // Only strings that plausibly carry markup or entities pay for the
    // fragment pass: a tag needs a letter after the angle, and a decodable
    // reference needs its semicolon. "Tom<Jerry" or a lone ampersand stay
    // untouched -- the parser would eat a bare "<Jerry" as an unknown tag
    // start and a title is not worth that risk.
    if (_hasMarkupOrEntity(text)) {
      text = _stripMarkup(text);
    }
    return text.trim();
  }

  bool _hasMarkupOrEntity(String text) {
    return RegExp(r'&#?[a-zA-Z0-9]{1,10};|<[a-zA-Z/][^>]{0,200}>')
        .hasMatch(text);
  }

  /// Breaks the tags paragraphs are wrapped in into line breaks and leaves
  /// the parser the rest.
  String _stripMarkup(String text) {
    var prepared = text
        .replaceAllMapped(
          RegExp(r'<br\s*/?>', caseSensitive: false),
          (_) => '\n',
        )
        .replaceAllMapped(
          RegExp(r'</(p|div)\s*>', caseSensitive: false),
          (_) => '\n\n',
        );
    prepared = parseFragment(prepared).text ?? prepared;
    // Whitespace overrun is only from the breaks this step itself wrote; a
    // collapse keeps a description from growing pages of empty lines.
    return prepared
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n');
  }

  /// Re-reads [text] as UTF-8 that was mis-decoded through Windows-1252.
  ///
  /// Returns [text] as-is when it is clean, or whenever the whole-line
  /// repair is not safe: a character outside the single-byte window (real
  /// typographic text has those, mojibake never does), or a byte stream
  /// that does not decode. Several passes so text mangled more than once
  /// recovers fully.
  String _redecodeMisEncodedUtf8(String text) {
    var current = text;
    for (var pass = 0; pass < 3; pass++) {
      // The lead-byte glyphs `â`, `Ã`, `Â` start nearly every mis-decoded
      // run; a line without any of them has nothing for this to do.
      if (!current.contains('â') &&
          !current.contains('Ã') &&
          !current.contains('Â')) {
        return current;
      }
      final repaired = _singleCp1252Window(current);
      if (repaired == null || repaired == current) return current;
      current = repaired;
    }
    return current;
  }

  /// One pass of the re-read, or null when [text] must not be touched.
  String? _singleCp1252Window(String text) {
    final bytes = List<int>.filled(text.length, 0, growable: false);
    for (var i = 0; i < text.length; i++) {
      final cu = text.codeUnitAt(i);
      if (cu >= 0x20 && cu <= 0x7E) {
        // ASCII reads back out as the same byte.
        bytes[i] = cu;
      } else if (cu == 0x09 || cu == 0x0A || cu == 0x0D) {
        // Tab, newline and carriage return are identical bytes on both
        // sides of the mis-decode; descriptions legitimately carry them.
        bytes[i] = cu;
      } else if (cu < 0x20 || cu <= 0x9F) {
        // Any other C0 control, or a C1 control (0x80-0x9F as a code
        // point), is never produced by this kind of mis-decode; its
        // presence says the text is not what the glyph gate claims.
        return null;
      } else if (cu <= 0xFF) {
        // Latin-1 supplement: the byte and the code point coincide.
        bytes[i] = cu;
      } else {
        // Everything above Latin-1 has to be one of Windows-1252's
        // remapped bytes -- €, ”, … are what `â`'s middle glyph renders
        // from -- otherwise the line mixes real typographic text with
        // mojibake and the whole-string re-read cannot reach it.
        final byte = _cp1252ByteForChar[cu];
        if (byte == null) return null;
        bytes[i] = byte;
      }
    }
    try {
      // Strict on purpose: a decorated line that merely trips the
      // lead-glyph gate decodes to noise here and is left alone, which
      // corrupting it would not be.
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return null;
    }
  }

  /// Token patch-up for lines the wholesale re-read could not take.
  ///
  /// Longest forms before their prefixes, always: the catch-all sits last
  /// so it only mops up bytes the table above did not list.
  String _patchResidualArtefacts(String text) {
    return text
        .replaceAll('â€™', "'")
        .replaceAll('â€œ', '"')
        .replaceAll('â€˜', "'")
        .replaceAll('â€¦', '…')
        .replaceAll('Â¡', '¡')
        .replaceAll('Â¿', '¿')
        .replaceAll('Â·', '·')
        .replaceAll('Â°', '°')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã¨', 'è')
        .replaceAll('Ãª', 'ê')
        .replaceAll('Ã«', 'ë')
        .replaceAll('Ã¡', 'á')
        .replaceAll('Ã\u00A0', 'à') // Ã + no-break space
        .replaceAll('Ã¢', 'â')
        .replaceAll('Ã£', 'ã')
        .replaceAll('Ã­', 'í')
        .replaceAll('Ã®', 'î')
        .replaceAll('Ã³', 'ó')
        .replaceAll('Ã²', 'ò')
        .replaceAll('Ã´', 'ô')
        .replaceAll('Ãµ', 'õ')
        .replaceAll('Ãº', 'ú')
        .replaceAll('Ã¹', 'ù')
        .replaceAll('Ã»', 'û')
        .replaceAll('Ã¼', 'ü')
        .replaceAll('Ã±', 'ñ')
        .replaceAll('Ã§', 'ç')
        .replaceAll('Ã¶', 'ö')
        .replaceAll('Ã¤', 'ä')
        .replaceAll('Ã–', 'Ö')
        .replaceAll('Ãœ', 'Ü')
        .replaceAll('Ã„', 'Ä')
        .replaceAll('Ã…', 'Å')
        .replaceAll('Ã˜', 'Ø')
        .replaceAll('Ã†', 'Æ')
        // The mis-decoded dash and the right quote share every byte, so no
        // token can tell them apart here; the wholesale re-read above is
        // what resolves them properly, so this stays leaned to a quote.
        .replaceAll('â€”', '"')
        // The catch-all: any remaining glyph after `â€` stood for one of
        // Windows-1252's unmapped control bytes -- 0x81, 0x8D, 0x8F, 0x90
        // and 0x9D carry no character -- which the sources' usual mix
        // parks inside quoted phrases, so a right quote is the closest
        // plain-text reading. Longest-first ordering keeps this last.
        .replaceAll('â€', '"');
  }
}

/// Windows-1252 bytes 0x80-0x9F carry real code points, not the C1 controls
/// Latin-1 would; a mis-decoded line renders them as these characters, so
/// the reverse table is what reads the byte back.
const Map<int, int> _cp1252ByteForChar = {
  0x20AC: 0x80, // €
  0x201A: 0x82, // ‚
  0x0192: 0x83, // ƒ
  0x201E: 0x84, // „
  0x2026: 0x85, // …
  0x2020: 0x86, // †
  0x2021: 0x87, // ‡
  0x02C6: 0x88, // ˆ
  0x2030: 0x89, // ‰
  0x0160: 0x8A, // Š
  0x2039: 0x8B, // ‹
  0x0152: 0x8C, // Œ
  0x017D: 0x8E, // Ž
  0x2018: 0x91, // '
  0x2019: 0x92, // '
  0x201C: 0x93, // "
  0x201D: 0x94, // "
  0x2022: 0x95, // •
  0x2013: 0x96, // –
  0x2014: 0x97, // —
  0x02DC: 0x98, // ˜
  0x2122: 0x99, // ™
  0x0161: 0x9A, // š
  0x203A: 0x9B, // ›
  0x0153: 0x9C, // œ
  0x017E: 0x9E, // ž
  0x0178: 0x9F, // Ÿ
};
