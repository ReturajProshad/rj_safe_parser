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
/// [jsonKey] is the key name in the JSON (may differ from Dart field name).
class RjTypeSchema<T> extends RjFieldSchema {
  /// The JSON key name (may differ from Dart field name when using @RjKey).
  final String jsonKey;

  const RjTypeSchema({this.jsonKey = ''});

  @override
  String toString() => 'RjTypeSchema<$T>(jsonKey: ${jsonKey.isEmpty ? '<field>' : jsonKey})';
}

// ─── List ─────────────────────────────────────────────────────────────────────

/// Schema for `List<E>` fields. [itemSchema] describes each element.
///
/// [jsonKey] is the key name in the JSON (may differ from Dart field name).
class RjListSchema extends RjFieldSchema {
  /// The JSON key name (may differ from Dart field name when using @RjKey).
  final String jsonKey;
  final RjFieldSchema itemSchema;

  const RjListSchema(this.itemSchema, {this.jsonKey = ''});

  @override
  String toString() => 'RjListSchema($itemSchema, jsonKey: ${jsonKey.isEmpty ? '<field>' : jsonKey})';
}

// ─── Nested object ────────────────────────────────────────────────────────────

/// Schema for a nested object (another `@RjSafeParsable` class).
/// [fieldSchemas] is the generated `_$SomeClassSchema` map of that class.
///
/// [jsonKey] is the key name in the JSON (may differ from Dart field name).
class RjObjectSchema extends RjFieldSchema {
  /// The JSON key name (may differ from Dart field name when using @RjKey).
  final String jsonKey;
  final Map<String, RjFieldSchema> fieldSchemas;

  const RjObjectSchema(this.fieldSchemas, {this.jsonKey = ''});

  @override
  String toString() => 'RjObjectSchema({${fieldSchemas.keys.join(', ')}}, jsonKey: ${jsonKey.isEmpty ? '<field>' : jsonKey})';
}
