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

      // Distinguish "key present with null value" from "key absent" so that
      // required fields correctly throw on absence regardless of null-safety.
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

  /// Returns the JSON key to look up in the source map for a given schema entry.
  /// Falls back to the Dart field name when no custom key was set.
  String _jsonKeyOf(RjFieldSchema schema, String dartField) {
    if (schema is RjTypeSchema && schema.jsonKey.isNotEmpty) {
      return schema.jsonKey;
    }
    if (schema is RjListSchema && schema.jsonKey.isNotEmpty) {
      return schema.jsonKey;
    }
    if (schema is RjObjectSchema && schema.jsonKey.isNotEmpty) {
      return schema.jsonKey;
    }
    return dartField;
  }

  // ── Recursive coercion ─────────────────────────────────────────────────────

  dynamic _coerceField(
    dynamic raw,
    RjFieldSchema schema,
    String path,
    List<String> warnings, {
    bool keyPresent = true,
  }) {
    if (schema is RjTypeSchema) {
      return _coerceType(raw, schema, path, keyPresent: keyPresent);
    }
    if (schema is RjListSchema) {
      return _coerceList(raw, schema, path, warnings, keyPresent: keyPresent);
    }
    if (schema is RjObjectSchema) {
      return _coerceObject(raw, schema, path, warnings);
    }
    throw RjParseException(
      'Unsupported schema type: ${schema.runtimeType}',
      fieldPath: path,
    );
  }

  // ── Primitive coercion ─────────────────────────────────────────────────────
  //
  // Reads typeName and isNullable directly from the schema — no toString()
  // parsing, no fragile string extraction.

  dynamic _coerceType(
    dynamic raw,
    RjTypeSchema schema,
    String path, {
    bool keyPresent = true,
  }) {
    // A nullable field whose key is absent returns null without error.
    if (schema.isNullable && !keyPresent) return null;

    return rjCoerceValue(
      raw,
      schema.typeName,
      path,
      nullable: schema.isNullable,
      dateFormat: dateFormat,
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
    // Nullable list field: absent key or explicit null → null (not empty list).
    if (schema.isNullable) {
      if (!keyPresent || raw == null) return const [];
    } else {
      // Required (non-nullable) list: absent key is an error.
      if (!keyPresent) {
        throw RjParseException(
          'Required List field is missing.',
          fieldPath: path,
        );
      }
      // Explicit null for a required list is also an error.
      if (raw == null) {
        throw RjParseException(
          'Expected List, got null.',
          fieldPath: path,
        );
      }
    }

    if (raw is! List) {
      throw RjParseException(
        'Expected List, got ${raw.runtimeType}',
        fieldPath: path,
      );
    }

    // Index-based loop so path entries include [0], [1], etc.
    final result = <dynamic>[];
    for (var i = 0; i < raw.length; i++) {
      result.add(
        _coerceField(raw[i], schema.itemSchema, '$path[$i]', warnings),
      );
    }
    return result;
  }

  // ── Object coercion ────────────────────────────────────────────────────────

  Map<String, dynamic> _coerceObject(
    dynamic raw,
    RjObjectSchema schema,
    String path,
    List<String> warnings,
  ) {
    if (schema.isNullable && raw == null) {
      // Nullable nested object — caller's cast expression handles the null.
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
