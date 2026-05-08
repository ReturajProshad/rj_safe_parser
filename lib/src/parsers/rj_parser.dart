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
      final jsonKey = _extractJsonKey(fieldSchema, dartField);
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
      final jsonKey = _extractJsonKey(fieldSchema, dartField);
      final rawValue = source[jsonKey]; // null if key absent
      data[dartField] =
          _coerceField(rawValue, fieldSchema, fieldPath, warnings);
    }

    return RjParseResult(data: data, warnings: warnings);
  }

  /// Extracts the JSON key from a schema object.
  /// Falls back to the Dart field name if no custom key is set.
  String _extractJsonKey(RjFieldSchema schema, String dartField) {
    if (schema is RjTypeSchema) {
      return schema.jsonKey.isEmpty ? dartField : schema.jsonKey;
    }
    if (schema is RjListSchema) {
      return schema.jsonKey.isEmpty ? dartField : schema.jsonKey;
    }
    if (schema is RjObjectSchema) {
      return schema.jsonKey.isEmpty ? dartField : schema.jsonKey;
    }
    return dartField;
  }

  // ── Recursive coercion ─────────────────────────────────────────────────────

  dynamic _coerceField(
    dynamic raw,
    RjFieldSchema schema,
    String path,
    List<String> warnings,
  ) {
    if (schema is RjTypeSchema) return _coerceType(raw, schema, path);
    if (schema is RjListSchema) return _coerceList(raw, schema, path, warnings);
    if (schema is RjObjectSchema) {
      return _coerceObject(raw, schema, path, warnings);
    }
    throw RjParseException(
      'Unsupported schema type: ${schema.runtimeType}',
      fieldPath: path,
    );
  }

  dynamic _coerceType(dynamic raw, RjTypeSchema schema, String path) {
    // Extract 'int' from 'RjTypeSchema<int>' or 'int?' from 'RjTypeSchema<int?>'
    // The toString() now includes jsonKey, e.g., 'RjTypeSchema<int>(jsonKey: id)'
    final typeParam = _extractTypeParamFromSchema(schema);
    // Nullability comes from the declared type (T?), NOT from whether the
    // raw value happens to be null. A null value for a required (non-?) field
    // must throw, not silently return null.
    final nullable = typeParam.endsWith('?');
    final typeName =
        nullable ? typeParam.substring(0, typeParam.length - 1) : typeParam;
    return rjCoerceValue(
      raw,
      typeName,
      path,
      nullable: nullable,
      dateFormat: dateFormat,
    );
  }

  /// Extracts the type parameter from schema toString() output.
  /// Handles both old format 'RjTypeSchema<int>' and new format
  /// 'RjTypeSchema<int>(jsonKey: ...)'.
  static String _extractTypeParamFromSchema(RjTypeSchema schema) {
    final str = schema.toString();
    final start = str.indexOf('<');
    final end = str.indexOf('>');
    if (start == -1 || end == -1) return str;
    return str.substring(start + 1, end);
  }

  List<dynamic> _coerceList(
    dynamic raw,
    RjListSchema schema,
    String path,
    List<String> warnings,
  ) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw RjParseException(
        'Expected List, got ${raw.runtimeType}',
        fieldPath: path,
      );
    }
    // Use index-based iteration so path includes [0], [1], etc.
    final result = <dynamic>[];
    for (var i = 0; i < raw.length; i++) {
      result.add(
        _coerceField(raw[i], schema.itemSchema, '$path[$i]', warnings),
      );
    }
    return result;
  }

  Map<String, dynamic> _coerceObject(
    dynamic raw,
    RjObjectSchema schema,
    String path,
    List<String> warnings,
  ) {
    if (raw == null) {
      throw RjParseException(
        'Expected Map (nested object), got null',
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

  /// Extracts `'int'` from `'RjTypeSchema<int>'`.
  static String _extractGenericParam(String s) {
    final start = s.indexOf('<');
    final end = s.lastIndexOf('>');
    if (start == -1 || end == -1) return s;
    return s.substring(start + 1, end);
  }
}
