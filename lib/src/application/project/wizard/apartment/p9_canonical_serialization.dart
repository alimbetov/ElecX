import 'dart:convert';

/// Collision-safe canonical serialization for P9 fingerprint inputs.
///
/// Each key/value segment is UTF-8 length-prefixed, so payload characters such
/// as `|`, `=`, `,` and newlines cannot alter field boundaries. Callers remain
/// responsible for supplying fields in their semantic canonical order.
String p9CanonicalSerializeFields(
  Iterable<MapEntry<String, String>> fields,
) {
  final buffer = StringBuffer();
  for (final field in fields) {
    _writeSegment(buffer, field.key);
    _writeSegment(buffer, field.value);
  }
  return buffer.toString();
}

/// Canonically serializes a string map by sorting keys lexicographically.
String p9CanonicalSerializeStringMap(Map<String, String> values) {
  final entries = values.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return p9CanonicalSerializeFields(entries);
}

void _writeSegment(StringBuffer buffer, String value) {
  final byteLength = utf8.encode(value).length;
  buffer
    ..write(byteLength)
    ..write(':')
    ..write(value);
}
