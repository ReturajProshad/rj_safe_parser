# Changelog

## 0.1.0

- Initial release of `rj_safe_parser`
- `@RjSafeParsable()` class-level annotation — zero per-field boilerplate
- Smart coercion for `String`, `int`, `double`, `bool`, `DateTime`, `Uri`
- Support for nullable fields (`T?` = optional, absent key → null)
- Support for `List<T>` and `List<NestedModel>`
- Support for nested `@RjSafeParsable()` models
- Strict mode — rejects unknown keys when `strict: true`
- Dot-path error reporting in `RjParseException` (e.g. `address.zip`)
- `RjParseResult` warnings for non-fatal issues (unknown keys in lenient mode)
- `build_runner` code generator via `RjSafeParserGenerator`
- Comprehensive runtime tests (no build_runner required to run tests)
