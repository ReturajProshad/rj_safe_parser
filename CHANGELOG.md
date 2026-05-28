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
