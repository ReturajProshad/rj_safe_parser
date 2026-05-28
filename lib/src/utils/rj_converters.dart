/// Smart coercion helpers used internally by [RjSafeMapParser].
///
/// Each `rjCoerce*` function accepts the raw value from the source map
/// (which may be a "wrong but close" type, e.g. `'7'` instead of `7`)
/// and returns the correct Dart type — or throws [RjParseException].
library rj_safe_parser.converters;

import 'rj_parse_result.dart';

// ─── String ───────────────────────────────────────────────────────────────────

String rjCoerceString(dynamic v, String path) {
  if (v == null) {
    throw RjParseException('Expected String, got null', fieldPath: path);
  }
  return v.toString();
}

String? rjCoerceStringNullable(dynamic v, String path) =>
    v == null ? null : rjCoerceString(v, path);

// ─── int ──────────────────────────────────────────────────────────────────────

int rjCoerceInt(dynamic v, String path) {
  if (v == null) {
    throw RjParseException('Expected int, got null', fieldPath: path);
  }
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  if (v is String) {
    final n = int.tryParse(v) ?? double.tryParse(v)?.toInt();
    if (n != null) return n;
  }
  throw RjParseException(
    'Cannot coerce ${v.runtimeType} "$v" → int',
    fieldPath: path,
  );
}

int? rjCoerceIntNullable(dynamic v, String path) =>
    v == null ? null : rjCoerceInt(v, path);

// ─── double ───────────────────────────────────────────────────────────────────

double rjCoerceDouble(dynamic v, String path) {
  if (v == null) {
    throw RjParseException('Expected double, got null', fieldPath: path);
  }
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) {
    final n = double.tryParse(v);
    if (n != null) return n;
  }
  throw RjParseException(
    'Cannot coerce ${v.runtimeType} "$v" → double',
    fieldPath: path,
  );
}

double? rjCoerceDoubleNullable(dynamic v, String path) =>
    v == null ? null : rjCoerceDouble(v, path);

// ─── bool ─────────────────────────────────────────────────────────────────────

bool rjCoerceBool(dynamic v, String path) {
  if (v == null) {
    throw RjParseException('Expected bool, got null', fieldPath: path);
  }
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  throw RjParseException(
    'Cannot coerce ${v.runtimeType} "$v" → bool. '
    'Accepted string values: true/false, yes/no, 1/0.',
    fieldPath: path,
  );
}

bool? rjCoerceBoolNullable(dynamic v, String path) =>
    v == null ? null : rjCoerceBool(v, path);

// ─── DateTime ─────────────────────────────────────────────────────────────────

DateTime rjCoerceDateTime(dynamic v, String path, {String? format}) {
  if (v == null) {
    throw RjParseException('Expected DateTime, got null', fieldPath: path);
  }
  if (v is DateTime) return v;

  // Unix timestamp — heuristic: > 10_000_000_000 → milliseconds, else seconds
  if (v is int) {
    return v > 10000000000
        ? DateTime.fromMillisecondsSinceEpoch(v, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true);
  }

  if (v is double) {
    return DateTime.fromMillisecondsSinceEpoch(
      (v * 1000).toInt(),
      isUtc: true,
    );
  }

  if (v is String) {
    final iso = DateTime.tryParse(v);
    if (iso != null) return iso;

    final asInt = int.tryParse(v);
    if (asInt != null) return rjCoerceDateTime(asInt, path, format: format);

    throw RjParseException(
      'Cannot parse "$v" as DateTime. '
      'Accepted: ISO-8601 string or Unix timestamp int/double.',
      fieldPath: path,
    );
  }

  throw RjParseException(
    'Cannot coerce ${v.runtimeType} "$v" → DateTime',
    fieldPath: path,
  );
}

DateTime? rjCoerceDateTimeNullable(dynamic v, String path, {String? format}) =>
    v == null ? null : rjCoerceDateTime(v, path, format: format);

// ─── Uri ──────────────────────────────────────────────────────────────────────

Uri rjCoerceUri(dynamic v, String path) {
  if (v == null) {
    throw RjParseException('Expected Uri, got null', fieldPath: path);
  }
  if (v is Uri) return v;
  if (v is String) {
    final u = Uri.tryParse(v);
    if (u != null) return u;
    throw RjParseException('Cannot parse "$v" as Uri', fieldPath: path);
  }
  throw RjParseException(
    'Cannot coerce ${v.runtimeType} "$v" → Uri',
    fieldPath: path,
  );
}

Uri? rjCoerceUriNullable(dynamic v, String path) =>
    v == null ? null : rjCoerceUri(v, path);

// ─── Enum ─────────────────────────────────────────────────────────────────────

/// Coerces [v] to one of the enum constants in [values].
///
/// When [byIndex] is false (default), [v] must be a String matching an enum
/// constant's `.name`. When [byIndex] is true, [v] must be an int (or
/// coercible numeric string) that is a valid index in [values].
///
/// Throws [RjParseException] if the value cannot be matched.
T rjCoerceEnum<T extends Enum>(
  dynamic v,
  List<T> values,
  String path, {
  bool byIndex = false,
}) {
  if (v == null) {
    throw RjParseException('Expected enum ${T.toString()}, got null',
        fieldPath: path);
  }

  if (byIndex) {
    // Accept int or numeric string
    final idx = v is int ? v : int.tryParse(v.toString());
    if (idx == null) {
      throw RjParseException(
        'Cannot coerce ${v.runtimeType} "$v" → ${T.toString()} index: '
        'expected an integer.',
        fieldPath: path,
      );
    }
    if (idx < 0 || idx >= values.length) {
      throw RjParseException(
        'Enum index $idx is out of range for ${T.toString()} '
        '(valid: 0–${values.length - 1}).',
        fieldPath: path,
      );
    }
    return values[idx];
  }

  // By name — accept String or stringify anything else
  final name = v.toString();
  for (final constant in values) {
    if (constant.name == name) return constant;
  }
  final validNames = values.map((e) => e.name).join(', ');
  throw RjParseException(
    'Cannot match "$name" to any constant in ${T.toString()}. '
    'Valid names: $validNames.',
    fieldPath: path,
  );
}

T? rjCoerceEnumNullable<T extends Enum>(
  dynamic v,
  List<T> values,
  String path, {
  bool byIndex = false,
}) =>
    v == null ? null : rjCoerceEnum(v, values, path, byIndex: byIndex);

// ─── Map ──────────────────────────────────────────────────────────────────────

/// Coerces a raw JSON map to `Map<String, V>` by applying [coerceValue] to
/// each entry's value.
///
/// Keys are always treated as Strings (JSON only supports string keys).
/// Throws [RjParseException] if [raw] is not a [Map].
Map<String, dynamic> rjCoerceMap(
  dynamic raw,
  String path, {
  required dynamic Function(dynamic value, String entryPath) coerceValue,
}) {
  if (raw == null) {
    throw RjParseException('Expected Map, got null', fieldPath: path);
  }
  if (raw is! Map) {
    throw RjParseException(
      'Expected Map, got ${raw.runtimeType}',
      fieldPath: path,
    );
  }
  final result = <String, dynamic>{};
  for (final entry in raw.entries) {
    final key = entry.key.toString();
    final entryPath = '$path.$key';
    result[key] = coerceValue(entry.value, entryPath);
  }
  return result;
}

Map<String, dynamic>? rjCoerceMapNullable(
  dynamic raw,
  String path, {
  required dynamic Function(dynamic value, String entryPath) coerceValue,
}) =>
    raw == null ? null : rjCoerceMap(raw, path, coerceValue: coerceValue);

// ─── Dispatcher (used by RjSafeMapParser internally) ─────────────────────────

/// Coerces [value] to the type named by [typeName].
/// [nullable] = true means null is a valid result (field is typed `T?`).
dynamic rjCoerceValue(
  dynamic value,
  String typeName,
  String path, {
  bool nullable = false,
  String? dateFormat,
}) {
  if (nullable && value == null) return null;

  switch (typeName) {
    case 'String':
      return nullable
          ? rjCoerceStringNullable(value, path)
          : rjCoerceString(value, path);
    case 'int':
      return nullable
          ? rjCoerceIntNullable(value, path)
          : rjCoerceInt(value, path);
    case 'double':
      return nullable
          ? rjCoerceDoubleNullable(value, path)
          : rjCoerceDouble(value, path);
    case 'bool':
      return nullable
          ? rjCoerceBoolNullable(value, path)
          : rjCoerceBool(value, path);
    case 'DateTime':
      return nullable
          ? rjCoerceDateTimeNullable(value, path, format: dateFormat)
          : rjCoerceDateTime(value, path, format: dateFormat);
    case 'Uri':
      return nullable
          ? rjCoerceUriNullable(value, path)
          : rjCoerceUri(value, path);
    default:
      throw RjParseException(
        'No coercer registered for type "$typeName".',
        fieldPath: path,
      );
  }
}
