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
  final String jsonKey;
  final String typeName;
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

// ─── Enum ─────────────────────────────────────────────────────────────────────

/// Schema for a Dart `enum` field (annotated with `@RjEnum()` or inferred).
///
/// [enumValues] — the full `EnumType.values` list, passed in by the generated
///               schema constant so the runtime can perform name/index lookup
///               without `dart:mirrors`.
/// [byIndex]    — when true, the JSON value is an int index into [enumValues];
///               when false (default), the JSON value is the enum `.name` string.
/// [jsonKey]    — the key name in the JSON map.
/// [isNullable] — true when the field is declared as `EnumType?`.
class RjEnumSchema extends RjFieldSchema {
  final List<Enum> enumValues;
  final bool byIndex;
  final String jsonKey;
  final bool isNullable;

  const RjEnumSchema({
    required this.enumValues,
    this.byIndex = false,
    this.jsonKey = '',
    this.isNullable = false,
  });

  @override
  String toString() =>
      'RjEnumSchema(${enumValues.runtimeType}, byIndex: $byIndex, '
      'isNullable: $isNullable, jsonKey: ${jsonKey.isEmpty ? '<field>' : jsonKey})';
}

// ─── Map ──────────────────────────────────────────────────────────────────────

/// Schema for `Map<String, V>` fields.
///
/// Keys are always treated as Strings (JSON only supports string keys).
/// [valueSchema] describes how each map value is coerced.
///
/// [jsonKey]    — the key name in the JSON map.
/// [isNullable] — true when the field is declared as `Map<String, V>?`.
class RjMapSchema extends RjFieldSchema {
  final RjFieldSchema valueSchema;
  final String jsonKey;
  final bool isNullable;

  const RjMapSchema(this.valueSchema,
      {this.jsonKey = '', this.isNullable = false});

  @override
  String toString() => 'RjMapSchema($valueSchema, isNullable: $isNullable, '
      'jsonKey: ${jsonKey.isEmpty ? '<field>' : jsonKey})';
}

// ─── List ─────────────────────────────────────────────────────────────────────

/// Schema for `List<E>` fields. [itemSchema] describes each element.
///
/// [jsonKey]    — the key name in the JSON (may differ from Dart field name).
/// [isNullable] — true when the field is declared as `List<E>?`.
///               A non-nullable list with a missing key throws [RjParseException].
class RjListSchema extends RjFieldSchema {
  final String jsonKey;
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
///
/// [jsonKey]    — the key name in the JSON (may differ from Dart field name).
/// [isNullable] — true when the field is declared as `NestedModel?`.
class RjObjectSchema extends RjFieldSchema {
  final String jsonKey;
  final bool isNullable;
  final Map<String, RjFieldSchema> fieldSchemas;

  const RjObjectSchema(this.fieldSchemas,
      {this.jsonKey = '', this.isNullable = false});

  @override
  String toString() =>
      'RjObjectSchema({${fieldSchemas.keys.join(', ')}}, isNullable: $isNullable, '
      'jsonKey: ${jsonKey.isEmpty ? '<field>' : jsonKey})';
}
