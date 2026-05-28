import '../models/rj_schema.dart';
import '../utils/rj_parse_result.dart';
import '../utils/rj_converters.dart';

/// The runtime engine that walks a raw `Map<String, dynamic>` and coerces
/// every value according to its [RjFieldSchema].
///
/// Generated `fromMap()` functions call this internally. You can also
/// use it directly for manual parsing or testing:
///
/// ```dart
/// final parser = RjSafeMapParser();
/// final result = parser.parse(rawMap, _$UserModelSchema);
/// final id = result.data['id'] as int;
/// ```
class RjSafeMapParser {
  /// See [RjSafeParsable.strict].
  final bool strict;

  /// See [RjSafeParsable.dateFormat].
  final String? dateFormat;

  const RjSafeMapParser({this.strict = false, this.dateFormat});

  /// Validates and coerces [source] against [schema].
  ///
  /// Returns an [RjParseResult] whose `.data` map contains coerced values.
  /// Throws [RjParseException] on unrecoverable errors.
  RjParseResult parse(
    Map<String, dynamic> source,
    Map<String, RjFieldSchema> schema, {
    String parentPath = '',
  }) {
    final data = <String, dynamic>{};
    final warnings = <String>[];

    // ── Build reverse lookup: JSON key → Dart field name ─────────────────────
    final jsonKeyToField = <String, String>{};
    for (final entry in schema.entries) {
      final dartField = entry.key;
      final fieldSchema = entry.value;
      final jsonKey = _jsonKeyOf(fieldSchema, dartField);
      jsonKeyToField[jsonKey] = dartField;
    }

    // ── Strict mode: reject unknown keys ──────────────────────────────────────
    if (strict) {
      for (final key in source.keys) {
        if (!jsonKeyToField.containsKey(key)) {
          throw RjParseException(
            'Unknown key "$key" (strict mode is enabled).',
            fieldPath: _joinPath(parentPath, key),
          );
        }
      }
    } else {
      for (final key in source.keys) {
        if (!jsonKeyToField.containsKey(key)) {
          warnings.add(
            'Unknown key "${_joinPath(parentPath, key)}" was ignored.',
          );
        }
      }
    }

    // ── Walk every field declared in the schema ────────────────────────────────
    for (final entry in schema.entries) {
      final dartField = entry.key;
      final fieldSchema = entry.value;
      final fieldPath = _joinPath(parentPath, dartField);
      final jsonKey = _jsonKeyOf(fieldSchema, dartField);

      // Distinguish "key present with null value" from "key absent".
      final keyPresent = source.containsKey(jsonKey);
      final rawValue = source[jsonKey];

      data[dartField] = _coerceField(
        rawValue,
        fieldSchema,
        fieldPath,
        warnings,
        keyPresent: keyPresent,
      );
    }

    return RjParseResult(data: data, warnings: warnings);
  }

  /// Returns the JSON key for a schema entry, falling back to the Dart field name.
  String _jsonKeyOf(RjFieldSchema schema, String dartField) {
    String key = '';
    if (schema is RjTypeSchema) key = schema.jsonKey;
    if (schema is RjListSchema) key = schema.jsonKey;
    if (schema is RjObjectSchema) key = schema.jsonKey;
    if (schema is RjEnumSchema) key = schema.jsonKey;
    if (schema is RjMapSchema) key = schema.jsonKey;
    return key.isNotEmpty ? key : dartField;
  }

  // ── Recursive coercion ─────────────────────────────────────────────────────

  dynamic _coerceField(
    dynamic raw,
    RjFieldSchema schema,
    String path,
    List<String> warnings, {
    bool keyPresent = true,
  }) {
    if (schema is RjTypeSchema)
      return _coerceType(raw, schema, path, keyPresent: keyPresent);
    if (schema is RjListSchema)
      return _coerceList(raw, schema, path, warnings, keyPresent: keyPresent);
    if (schema is RjObjectSchema)
      return _coerceObject(raw, schema, path, warnings, keyPresent: keyPresent);
    if (schema is RjEnumSchema)
      return _coerceEnum(raw, schema, path, keyPresent: keyPresent);
    if (schema is RjMapSchema)
      return _coerceMap(raw, schema, path, warnings, keyPresent: keyPresent);

    throw RjParseException(
      'Unsupported schema type: ${schema.runtimeType}',
      fieldPath: path,
    );
  }

  // ── Primitive coercion ─────────────────────────────────────────────────────

  dynamic _coerceType(
    dynamic raw,
    RjTypeSchema schema,
    String path, {
    bool keyPresent = true,
  }) {
    if (schema.isNullable && !keyPresent) return null;
    return rjCoerceValue(
      raw,
      schema.typeName,
      path,
      nullable: schema.isNullable,
      dateFormat: dateFormat,
    );
  }

  // ── Enum coercion ──────────────────────────────────────────────────────────

  dynamic _coerceEnum(
    dynamic raw,
    RjEnumSchema schema,
    String path, {
    bool keyPresent = true,
  }) {
    if (schema.isNullable && !keyPresent) return null;
    if (schema.isNullable && raw == null) return null;

    if (!keyPresent) {
      throw RjParseException(
        'Required enum field is missing.',
        fieldPath: path,
      );
    }

    return rjCoerceEnum(
      raw,
      schema.enumValues,
      path,
      byIndex: schema.byIndex,
    );
  }

  // ── List coercion ──────────────────────────────────────────────────────────

  List<dynamic> _coerceList(
    dynamic raw,
    RjListSchema schema,
    String path,
    List<String> warnings, {
    bool keyPresent = true,
  }) {
    if (schema.isNullable) {
      if (!keyPresent || raw == null) return const [];
    } else {
      if (!keyPresent) {
        throw RjParseException('Required List field is missing.',
            fieldPath: path);
      }
      if (raw == null) {
        throw RjParseException('Expected List, got null.', fieldPath: path);
      }
    }

    if (raw is! List) {
      throw RjParseException(
        'Expected List, got ${raw.runtimeType}',
        fieldPath: path,
      );
    }

    final result = <dynamic>[];
    for (var i = 0; i < raw.length; i++) {
      result
          .add(_coerceField(raw[i], schema.itemSchema, '$path[$i]', warnings));
    }
    return result;
  }

  // ── Map coercion ───────────────────────────────────────────────────────────

  Map<String, dynamic>? _coerceMap(
    dynamic raw,
    RjMapSchema schema,
    String path,
    List<String> warnings, {
    bool keyPresent = true,
  }) {
    if (schema.isNullable) {
      if (!keyPresent || raw == null) return null;
    } else {
      if (!keyPresent) {
        throw RjParseException('Required Map field is missing.',
            fieldPath: path);
      }
      if (raw == null) {
        throw RjParseException('Expected Map, got null.', fieldPath: path);
      }
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
      result[key] = _coerceField(
        entry.value,
        schema.valueSchema,
        entryPath,
        warnings,
      );
    }
    return result;
  }

  // ── Object coercion ────────────────────────────────────────────────────────

  Map<String, dynamic> _coerceObject(
    dynamic raw,
    RjObjectSchema schema,
    String path,
    List<String> warnings, {
    bool keyPresent = true,
  }) {
    if (schema.isNullable && (!keyPresent || raw == null)) {
      return <String, dynamic>{};
    }
    if (raw == null) {
      throw RjParseException(
        'Expected Map (nested object), got null.',
        fieldPath: path,
      );
    }
    if (raw is! Map) {
      throw RjParseException(
        'Expected Map, got ${raw.runtimeType}',
        fieldPath: path,
      );
    }
    final child = parse(
      Map<String, dynamic>.from(raw),
      schema.fieldSchemas,
      parentPath: path,
    );
    warnings.addAll(child.warnings);
    return child.data;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _joinPath(String parent, String child) =>
      parent.isEmpty ? child : '$parent.$child';
}
