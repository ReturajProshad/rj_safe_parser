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
class RjTypeSchema<T> extends RjFieldSchema {
  const RjTypeSchema();

  @override
  String toString() => 'RjTypeSchema<$T>';
}

// ─── List ─────────────────────────────────────────────────────────────────────

/// Schema for `List<E>` fields. [itemSchema] describes each element.
class RjListSchema extends RjFieldSchema {
  final RjFieldSchema itemSchema;

  // FIX: NOT const — itemSchema is a runtime value, cannot be const.
  const RjListSchema(this.itemSchema);

  @override
  String toString() => 'RjListSchema($itemSchema)';
}

// ─── Nested object ────────────────────────────────────────────────────────────

/// Schema for a nested object (another `@RjSafeParsable` class).
/// [fieldSchemas] is the generated `_$SomeClassSchema` map of that class.
class RjObjectSchema extends RjFieldSchema {
  final Map<String, RjFieldSchema> fieldSchemas;

  const RjObjectSchema(this.fieldSchemas);

  @override
  String toString() => 'RjObjectSchema({${fieldSchemas.keys.join(', ')}})';
}
