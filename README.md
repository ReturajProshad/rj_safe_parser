# rj_safe_parser

**One annotation on the class. Zero per-field boilerplate.**

RJ Safe Parser is a Flutter/Dart package inspired by Spring Boot's `@Entity`.
Place `@RjSafeParsable()` once on a class, run `build_runner`, and get a
fully type-safe `fromMap()` / `toMap()` with smart coercion for free.

---

## Features

- ✅ **One annotation** — no `@JsonKey`, `@HiveField`, or per-field decoration
- ✅ **Smart coercion** — `'7'` → `int`, `1` → `bool`, Unix ts → `DateTime`, and more
- ✅ **Nested models** — detected automatically if also `@RjSafeParsable()`
- ✅ **Lists** — `List<String>`, `List<MyModel>` — all handled
- ✅ **Nullable fields** — `String?` = optional, absent key yields `null`
- ✅ **Strict mode** — reject unknown keys for hard validation
- ✅ **Dot-path errors** — exceptions include the full field path (e.g. `address.zip`)
- ✅ **Round-trip** — `toMap()` serialises back to the original shape
- ✅ **Flutter-safe** — pure Dart, no mirrors, tree-shakeable

---

## Quick start

### 1. Add to `pubspec.yaml`

```yaml
dependencies:
  rj_safe_parser: ^0.1.0

dev_dependencies:
  build_runner: ^2.4.0
```

### 2. Annotate your class

```dart
import 'package:rj_safe_parser/rj_safe_parser.dart';
part 'user_model.g.dart';

@RjSafeParsable()
class UserModel {
  final int id;
  final String name;
  final String? nickname;   // nullable → optional field
  final double score;
  final bool isActive;
  final DateTime createdAt;
  final Uri profileUrl;
  final AddressModel address;       // nested @RjSafeParsable class
  final List<String> tags;
  final List<AddressModel> history;

  const UserModel({ ... });

  factory UserModel.fromMap(Map<String, dynamic> map) => _$UserModelFromMap(map);
  Map<String, dynamic> toMap() => _$UserModelToMap(this);
}
```

### 3. Run the generator

```bash
dart run build_runner build
# or watch mode:
dart run build_runner watch
```

### 4. Use it — that's it

```dart
final user = UserModel.fromMap(dirtyJson);
// '7' → int, 1 → bool, 1712620800 → DateTime — all automatic
```

---

## Supported type coercions

| Dart type | Accepted raw input |
|-----------|-------------------|
| `int` | `int`, `double` (truncated), `bool`, numeric `String` |
| `double` | `double`, `int`, numeric `String` |
| `bool` | `bool`, `int` (0/1), `String` (`true/false/yes/no/1/0`) |
| `String` | any — `.toString()` called |
| `DateTime` | `DateTime`, Unix `int`/`double` (sec or ms), ISO-8601 `String` |
| `Uri` | `Uri`, any `String` |
| `List<T>` | `List` — each element coerced to `T` |
| `MyModel` | `Map<String, dynamic>` — if annotated with `@RjSafeParsable()` |

---

## Options

```dart
@RjSafeParsable(
  strict: true,              // reject unknown keys (default: false)
  dateFormat: 'yyyy-MM-dd',  // custom date format (default: ISO-8601 + Unix ts)
)
class MyModel { ... }
```

---

## Package structure

```
lib/
  rj_safe_parser.dart         ← public API export
  rj_builder.dart             ← build_runner entry point
  src/
    core/
      rj_annotation.dart      ← @RjSafeParsable definition
    models/
      rj_schema.dart          ← RjTypeSchema / RjListSchema / RjObjectSchema
    parsers/
      rj_parser.dart          ← RjSafeMapParser runtime engine
    utils/
      rj_parse_result.dart    ← RjParseResult + RjParseException
      rj_converters.dart      ← rjCoerce* functions
    generator/
      rj_safe_parser_generator.dart  ← build_runner code generator
example/
  rj_address_model.dart       ← nested model example
  rj_user_model.dart          ← full user model (all field types)
  rj_product_model.dart       ← simpler product model
test/
  rj_safe_parser_test.dart    ← comprehensive runtime tests
build.yaml
pubspec.yaml
```
