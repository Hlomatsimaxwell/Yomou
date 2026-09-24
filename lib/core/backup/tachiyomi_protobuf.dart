import 'dart:convert';
import 'dart:typed_data';

/// Minimal protobuf wire-format encoder/decoder for the Mihon `Backup`
/// message schema. Only the uint field numbers and wire types matter for
/// interop; no generated classes or external dependency is required.
class TachiyomiProtoCodec {
  TachiyomiProtoCodec._();

  static const int _wireVarint = 0;
  static const int _wireFixed64 = 1;
  static const int _wireBytes = 2;
  static const int _wireFixed32 = 5;

  static const int gzipMagic = 0x1f8b;

  /// Raw-decode a protobuf message into `field -> list of values`.
  /// Varint and fixed64 fields decode to [int]; fixed32 to [int] (raw bits);
  /// bytes/string fields decode to `Uint8List`; nested messages recurse.
  static Map<int, List<Object?>> decode(Uint8List data, [int start = 0]) {
    final result = <int, List<Object?>>{};
    var pos = start;
    while (pos < data.length) {
      final tag = _readVarint(data, pos, (v) => pos = v);
      pos = tag._newPos;
      if (tag.value == 0) break;
      final field = tag.value >> 3;
      final wire = tag.value & 7;
      switch (wire) {
        case _wireVarint:
          final v = _readVarint(data, pos, (p) => pos = p);
          pos = v._newPos;
          result.putIfAbsent(field, () => []).add(v.value);
        case _wireFixed32:
          if (pos + 4 > data.length) return result;
          final v = ByteData.sublistView(data, pos, pos + 4).getUint32(0, Endian.little);
          pos += 4;
          result.putIfAbsent(field, () => []).add(v);
        case _wireFixed64:
          if (pos + 8 > data.length) return result;
          final v = ByteData.sublistView(data, pos, pos + 8).getUint32(0, Endian.little);
          pos += 8;
          result.putIfAbsent(field, () => []).add(v);
        case _wireBytes:
          final len = _readVarint(data, pos, (p) => pos = p);
          pos = len._newPos;
          if (pos + len.value > data.length) return result;
          final bytes = Uint8List.sublistView(data, pos, pos + len.value);
          pos += len.value;
          // Heuristic: nested message if those bytes are valid protobuf-ish.
          result.putIfAbsent(field, () => []).add(bytes);
        default:
          return result;
      }
    }
    return result;
  }

  /// Attempts to interpret a length-delimited field value as a nested message.
  static Map<int, List<Object?>>? asMessage(Object? value) {
    if (value is! Uint8List) return null;
    try {
      return decode(value);
    } catch (_) {
      return null;
    }
  }

  static String asString(Object? value) => value is Uint8List
      ? utf8.decode(value)
      : (value?.toString() ?? '');

  static int asInt(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static bool asBool(Object? value) => value is int && value != 0;

  static double asFloat32(Object? value) {
    final raw = asInt(value);
    final data = ByteData(4);
    data.setUint32(0, raw, Endian.little);
    return data.getFloat32(0, Endian.little);
  }

  static Map<int, List<Object?>> extractMessage(
    Map<int, List<Object?>> source,
    int field,
  ) {
    final result = <int, List<Object?>>{};
    for (final v in source[field] ?? const <Object?>[]) {
      final nested = asMessage(v);
      if (nested != null) {
        for (final entry in nested.entries) {
          result.putIfAbsent(entry.key, () => []).addAll(entry.value);
        }
      }
    }
    return result;
  }
}

/// Builder that emits protobuf fields in Mihon Backup field-number order.
class ProtoWriter {
  final BytesBuilder _bytes = BytesBuilder();

  void writeVarintField(int field, int value) {
    _tag(field, 0);
    _writeVarint(value);
  }

  void writeInt64Field(int field, int value) => writeVarintField(field, value);

  void writeBoolField(int field, bool value) {
    if (value) writeVarintField(field, 1);
  }

  void writeStringField(int field, String value) {
    final bytes = utf8.encode(value);
    _tag(field, 2);
    _writeVarint(bytes.length);
    _bytes.add(bytes);
  }

  void writeFloat32Field(int field, double value) {
    if (value == 0) return;
    final data = ByteData(4);
    data.setFloat32(0, value, Endian.little);
    writeFixed32Field(field, data.getUint32(0, Endian.little));
  }

  void writeFixed32Field(int field, int raw) {
    final data = ByteData(4);
    data.setUint32(0, raw, Endian.little);
    _tag(field, 5);
    _bytes.add(data.buffer.asUint8List(data.offsetInBytes, 4));
  }

  void writeMessageField(int field, void Function(ProtoWriter body) build) {
    final inner = ProtoWriter();
    build(inner);
    final bytes = inner.takeBytes();
    if (bytes.isEmpty) return;
    _tag(field, 2);
    _writeVarint(bytes.length);
    _bytes.add(bytes);
  }

  Uint8List takeBytes() => _bytes.takeBytes();

  void _tag(int field, int wire) => _writeVarint((field << 3) | wire);

  void _writeVarint(int value) {
    var v = value;
    while (v >= 0x80) {
      _bytes.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    _bytes.addByte(v);
  }
}

class _VarintResult {
  const _VarintResult(this.value, this._newPos);
  final int value;
  final int _newPos;
}

_VarintResult _readVarint(Uint8List data, int pos, void Function(int) move) {
  var shift = 0;
  var result = 0;
  while (shift < 64) {
    if (pos >= data.length) break;
    final b = data[pos++];
    result |= (b & 0x7f) << shift;
    move(pos);
    if ((b & 0x80) == 0) break;
    shift += 7;
  }
  return _VarintResult(result, pos);
}