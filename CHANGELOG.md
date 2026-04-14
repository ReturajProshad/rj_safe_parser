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
