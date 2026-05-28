## 0.4.0

**Phase 2a — `enum` support and `Map<String, V>` support**

### New: `enum` field support

Dart `enum` fields are now fully supported — annotate with `@RjEnum()` or
leave it bare for by-name matching, or use `@RjEnum(byIndex: true)` for
ordinal matching.

```dart
enum Status { active, inactive, pending }
enum Priority { low, medium, high }

@RjSafeParsable()
class Task {
  @RjEnum()               // 'active' → Status.active
  final Status status;

  @RjEnum(byIndex: true)  // 0 → Priority.low, 2 → Priority.high
  final Priority priority;
}
```

- By name (default): JSON value must be the `.name` string of an enum constant.
- By index: JSON value must be an `int` (or numeric string) matching the
  constant's position in `values`.
- Nullable `Status?` fields: absent key or explicit `null` → `null`.
- `toMap()` serialises back to `.name` or `.index` automatically.
- Runtime: new `rjCoerceEnum` / `rjCoerceEnumNullable` helpers in `rj_converters.dart`.
- Schema: new `RjEnumSchema` in `rj_schema.dart` carries the `values` list,
  `byIndex` flag, `jsonKey`, and `isNullable`.

### New: `Map<String, V>` field support

Fields typed as `Map<String, V>` are now generated and parsed correctly.
The map's values are individually coerced using the same smart-coercion
engine as all other fields.

```dart
@RjSafeParsable()
class Config {
  final Map<String, String>  labels;   // {'env': 'prod'}
  final Map<String, int>     counts;   // {'retry': '3'} → {'retry': 3}
  final Map<String, bool>    flags;    // {'darkMode': 1} → {'darkMode': true}
  final Map<String, double>? rates;    // nullable, absent → null
}
```

- Only `Map<String, V>` is supported (JSON has string-only keys); using
  any other key type raises a code-generation error.
- Values are coerced using the same rules as their scalar counterparts.
- `toMap()` serialises map values (handles `DateTime`, `Uri`, nested models).
- Error paths include the map entry key: `scores.alice` for a bad entry.
- Runtime: new `rjCoerceMap` / `rjCoerceMapNullable` helpers.
- Schema: new `RjMapSchema` in `rj_schema.dart`.

### Other changes

- Generator now accepts a `FieldElement?` parameter in `_schemaExpression`
  so enum and map schemas can read field-level annotations.
- `_jsonKeyOf` in parser handles all five schema types cleanly.
- Full test coverage for both features — runtime tests only, no
  `build_runner` required.

---

## 0.2.0

**Phase 1 — Foundation fixes**

- **Fix: type extraction no longer uses `toString()` parsing.**
  `RjTypeSchema` now carries explicit `typeName: String` and `isNullable: bool`
  fields set by the code generator at build time. The runtime reads these
  directly — no string parsing, no fragile generic reflection.

- **Fix: required `List` fields now throw on missing key.**
  Previously a missing list key silently returned `[]` regardless of
  nullability. Now only nullable lists (`List<T>?`) accept a missing key;
  required lists throw `RjParseException` just like any other required field.

- **Fix: key-present vs key-absent distinction in the parser.**
  The parser now uses `Map.containsKey()` to distinguish a missing key from
  an explicitly null value, enabling correct error messages for both cases.

- **Fix: removed Flutter dependency.**
  `flutter_test` and `flutter_lints` removed from `dev_dependencies`.
  Replaced with `package:test` (already present) and `package:lints`.
  `rj_safe_parser` is a pure Dart package and never required Flutter.

- **Fix: `analysis_options.yaml` now includes `package:lints/recommended.yaml`**
  instead of `package:flutter_lints/flutter.yaml`.

- **Updated: `RjListSchema` and `RjObjectSchema` carry `isNullable` field.**
  The runtime uses this to distinguish nullable-absent (return null/empty)
  from required-absent (throw).

- **Updated: generator emits `isNullable` and `typeName` in all schema literals.**
  Regenerate `.g.dart` files with `dart run build_runner build --delete-conflicting-outputs`
  after upgrading.

- **Updated: test suite migrated from `flutter_test` to `package:test`.**
  All tests pass with `dart test` — no Flutter toolchain required.

---

## 0.1.0

- Initial release of `rj_safe_parser`
- `@RjSafeParsable()` — single class-level annotation, zero per-field boilerplate
- Smart type coercion for `String`, `int`, `double`, `bool`, `DateTime`, `Uri`
  - Numeric strings (`'7'`) → `int` / `double`
  - Integer `1`/`0` → `bool`
  - Unix timestamps (seconds and milliseconds) → `DateTime`
  - ISO-8601 strings → `DateTime`
- Nullable fields (`T?`) — absent key yields `null`, no exception
- `List<T>` and `List<NestedModel>` — each element individually coerced
- Nested `@RjSafeParsable()` models — auto-detected, schema built inline
- Strict mode (`strict: true`) — rejects unknown keys with `RjParseException`
- Lenient mode (default) — unknown keys produce warnings in `RjParseResult.warnings`
- Dot-path error reporting — `RjParseException` includes full field path (e.g. `address.zip`)
- `build_runner` code generator via `RjSafeParserGenerator`
- Comprehensive runtime tests — no `build_runner` required to run the test suite
