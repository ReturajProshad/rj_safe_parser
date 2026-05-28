/// Schema types used by [RjSafeMapParser] to describe the expected
/// structure of each field in a parsed map.
///
/// The code generator emits a `Map<String, RjFieldSchema>` constant for
/// every `@RjSafeParsable()` class. You never write these by hand.
library;

// ─── Base ─────────────────────────────────────────────────────────────────────

abstract class RjFieldSchema {
  const RjFieldSchema();
}

// ─── Leaf: a single coercible Dart type ───────────────────────────────────────

/// Schema for a primitive or directly-coercible type.
/// Supported: [String], [int], [double], [bool], [DateTime], [Uri].
///
/// [jsonKey]    — the key name in the JSON (may differ from Dart field name).
/// [typeName]   — the Dart type name as a string, e.g. `'int'`, `'DateTime'`.
///               Set explicitly by the code generator so the runtime never has
///               to extract it from `toString()` or generic reflection.
/// [isNullable] — true when the Dart field is declared as `T?`.
class RjTypeSchema<T> extends RjFieldSchema {
  /// The JSON key name (may differ from Dart field name when using @RjKey).
  final String jsonKey;

  /// Dart type name used by the runtime coercer — e.g. `'int'`, `'DateTime'`.
  /// Always set explicitly by the generator; never derived from toString().
  final String typeName;

  /// Whether the field is nullable (`T?`). Absent keys return null instead of
  /// throwing when this is true.
  final bool isNullable;

  const RjTypeSchema({
    this.jsonKey = '',
    required this.typeName,
    this.isNullable = false,
  });

  @override
  String toString() =>
      'RjTypeSchema<$T>(typeName: $typeName, isNullable: $isNullable, '
      'jsonKey: ${jsonKey.isEmpty ? '<field>' : jsonKey})';
}

// ─── List ─────────────────────────────────────────────────────────────────────

/// Schema for `List<E>` fields. [itemSchema] describes each element.
///
/// [jsonKey]    — the key name in the JSON (may differ from Dart field name).
/// [isNullable] — true when the field is declared as `List<E>?`.
///               A non-nullable list with a missing key throws [RjParseException].
class RjListSchema extends RjFieldSchema {
  /// The JSON key name (may differ from Dart field name when using @RjKey).
  final String jsonKey;

  /// Whether the list field itself is nullable (`List<E>?`).
  final bool isNullable;

  final RjFieldSchema itemSchema;

  const RjListSchema(this.itemSchema,
      {this.jsonKey = '', this.isNullable = false});

  @override
  String toString() => 'RjListSchema($itemSchema, isNullable: $isNullable, '
      'jsonKey: ${jsonKey.isEmpty ? '<field>' : jsonKey})';
}

// ─── Nested object ────────────────────────────────────────────────────────────

/// Schema for a nested object (another `@RjSafeParsable` class).
/// [fieldSchemas] is the generated `_$SomeClassSchema` map of that class.
///
/// [jsonKey]    — the key name in the JSON (may differ from Dart field name).
/// [isNullable] — true when the field is declared as `NestedModel?`.
class RjObjectSchema extends RjFieldSchema {
  /// The JSON key name (may differ from Dart field name when using @RjKey).
  final String jsonKey;

  /// Whether this nested object field is nullable.
  final bool isNullable;

  final Map<String, RjFieldSchema> fieldSchemas;

  const RjObjectSchema(this.fieldSchemas,
      {this.jsonKey = '', this.isNullable = false});

  @override
  String toString() =>
      'RjObjectSchema({${fieldSchemas.keys.join(', ')}}, isNullable: $isNullable, '
      'jsonKey: ${jsonKey.isEmpty ? '<field>' : jsonKey})';
}
