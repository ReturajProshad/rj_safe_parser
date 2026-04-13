// test/rj_safe_parser_test.dart
//
// Full integration tests for the RJ Safe Parser runtime.
// Run with: dart test
//
// NOTE: These tests exercise the runtime engine directly —
// no build_runner or code generation required.

import 'package:flutter_test/flutter_test.dart';
import 'package:rj_safe_parser/rj_safe_parser.dart';

void main() {
  // ── Shared schema for most tests ──────────────────────────────────────────
  final schema = <String, RjFieldSchema>{
    'id': RjTypeSchema<int>(),
    'name': RjTypeSchema<String>(),
    'score': RjTypeSchema<double>(),
    'isActive': RjTypeSchema<bool>(),
    'createdAt': RjTypeSchema<DateTime>(),
    'profileUrl': RjTypeSchema<Uri>(),
  };

  Map<String, dynamic> _base({
    dynamic id = 1,
    dynamic name = 'Alice',
    dynamic score = 1.0,
    dynamic isActive = true,
    dynamic createdAt = 0,
    dynamic profileUrl = 'http://example.com',
  }) =>
      {
        'id': id,
        'name': name,
        'score': score,
        'isActive': isActive,
        'createdAt': createdAt,
        'profileUrl': profileUrl,
      };

  // ── Type coercions ─────────────────────────────────────────────────────────
  group('RjSafeMapParser — type coercions', () {
    final parser = RjSafeMapParser();

    test('int from numeric string', () {
      final r = parser.parse(_base(id: '42'), schema);
      expect(r.data['id'], equals(42));
      expect(r.data['id'], isA<int>());
    });

    test('int from double', () {
      final r = parser.parse(_base(id: 3.9), schema);
      expect(r.data['id'], equals(3));
    });

    test('double from string', () {
      final r = parser.parse(_base(score: '3.14'), schema);
      expect(r.data['score'], closeTo(3.14, 0.0001));
    });

    test('double from int', () {
      final r = parser.parse(_base(score: 5), schema);
      expect(r.data['score'], equals(5.0));
      expect(r.data['score'], isA<double>());
    });

    test('bool from int 1', () {
      final r = parser.parse(_base(isActive: 1), schema);
      expect(r.data['isActive'], isTrue);
    });

    test('bool from int 0', () {
      final r = parser.parse(_base(isActive: 0), schema);
      expect(r.data['isActive'], isFalse);
    });

    test('bool from string "true"', () {
      final r = parser.parse(_base(isActive: 'true'), schema);
      expect(r.data['isActive'], isTrue);
    });

    test('bool from string "false"', () {
      final r = parser.parse(_base(isActive: 'false'), schema);
      expect(r.data['isActive'], isFalse);
    });

    test('bool from string "yes"', () {
      final r = parser.parse(_base(isActive: 'yes'), schema);
      expect(r.data['isActive'], isTrue);
    });

    test('DateTime from Unix int (seconds)', () {
      final r = parser.parse(_base(createdAt: 1712620800), schema);
      expect(r.data['createdAt'], isA<DateTime>());
      final dt = r.data['createdAt'] as DateTime;
      expect(dt.year, equals(2024));
    });

    test('DateTime from Unix int (milliseconds)', () {
      final r = parser.parse(_base(createdAt: 1712620800000), schema);
      expect(r.data['createdAt'], isA<DateTime>());
    });

    test('DateTime from ISO-8601 string', () {
      final r = parser.parse(
          _base(createdAt: '2024-04-09T00:00:00Z'), schema);
      expect(r.data['createdAt'], isA<DateTime>());
      final dt = r.data['createdAt'] as DateTime;
      expect(dt.year, equals(2024));
    });

    test('Uri from string', () {
      final r = parser.parse(
          _base(profileUrl: 'https://rj.dev/alice'), schema);
      expect(r.data['profileUrl'], isA<Uri>());
      expect((r.data['profileUrl'] as Uri).host, equals('rj.dev'));
    });

    test('String from int (toString coercion)', () {
      final r = parser.parse(_base(name: 99), schema);
      expect(r.data['name'], equals('99'));
    });
  });

  // ── Nullable fields ────────────────────────────────────────────────────────
  group('RjSafeMapParser — nullable fields', () {
    final nullableSchema = <String, RjFieldSchema>{
      'name': RjTypeSchema<String?>(),
    };
    final parser = RjSafeMapParser();

    test('absent nullable key → null in result', () {
      final r = parser.parse({}, nullableSchema);
      expect(r.data.containsKey('name'), isTrue);
      expect(r.data['name'], isNull);
    });

    test('explicit null nullable key → null', () {
      final r = parser.parse({'name': null}, nullableSchema);
      expect(r.data['name'], isNull);
    });
  });

  // ── List fields ────────────────────────────────────────────────────────────
  group('RjSafeMapParser — list fields', () {
    final parser = RjSafeMapParser();

    test('List<String> passes through', () {
      final s = {'tags': RjListSchema(RjTypeSchema<String>())};
      final r = parser.parse({'tags': ['a', 'b', 'c']}, s);
      expect(r.data['tags'], equals(['a', 'b', 'c']));
    });

    test('missing list → empty list (no exception)', () {
      final s = {'tags': RjListSchema(RjTypeSchema<String>())};
      final r = parser.parse({}, s);
      expect(r.data['tags'], isEmpty);
    });

    test('List<int> coerced from strings', () {
      final s = {'ids': RjListSchema(RjTypeSchema<int>())};
      final r = parser.parse({'ids': ['1', '2', '3']}, s);
      expect(r.data['ids'], equals([1, 2, 3]));
    });
  });

  // ── Nested object ──────────────────────────────────────────────────────────
  group('RjSafeMapParser — nested objects', () {
    final addressSchema = <String, RjFieldSchema>{
      'city': RjTypeSchema<String>(),
      'zip': RjTypeSchema<int>(),
    };
    final userSchema = <String, RjFieldSchema>{
      'id': RjTypeSchema<int>(),
      'address': RjObjectSchema(addressSchema),
    };
    final parser = RjSafeMapParser();

    test('nested object parsed correctly', () {
      final r = parser.parse({
        'id': 1,
        'address': {'city': 'Dhaka', 'zip': '1212'},
      }, userSchema);
      expect(r.data['id'], equals(1));
      final addr = r.data['address'] as Map<String, dynamic>;
      expect(addr['city'], equals('Dhaka'));
      expect(addr['zip'], equals(1212)); // coerced from string
    });

    test('nested zip coerced from string to int', () {
      final r = parser.parse({
        'id': 1,
        'address': {'city': 'Chittagong', 'zip': '4000'},
      }, userSchema);
      final addr = r.data['address'] as Map<String, dynamic>;
      expect(addr['zip'], isA<int>());
    });
  });

  // ── Strict mode ────────────────────────────────────────────────────────────
  group('RjSafeMapParser — strict mode', () {
    final strict = RjSafeMapParser(strict: true);
    final lenient = RjSafeMapParser();

    test('unknown key throws in strict mode', () {
      expect(
        () => strict.parse(
          {'id': 1, 'extra': 'oops'},
          {'id': RjTypeSchema<int>()},
        ),
        throwsA(isA<RjParseException>()),
      );
    });

    test('unknown key is warned (not thrown) in lenient mode', () {
      final r = lenient.parse(
        {'id': 1, 'extra': 'oops'},
        {'id': RjTypeSchema<int>()},
      );
      expect(r.data['id'], equals(1));
      expect(r.hasWarnings, isTrue);
      expect(r.warnings.any((w) => w.contains('extra')), isTrue);
    });
  });

  // ── Error cases ────────────────────────────────────────────────────────────
  group('RjSafeMapParser — error cases', () {
    final parser = RjSafeMapParser();

    test('null required int throws RjParseException', () {
      expect(
        () => parser.parse({'id': null}, {'id': RjTypeSchema<int>()}),
        throwsA(isA<RjParseException>()),
      );
    });

    test('uncoercible string throws RjParseException', () {
      expect(
        () => parser.parse({'id': 'not_a_number'}, {'id': RjTypeSchema<int>()}),
        throwsA(isA<RjParseException>()),
      );
    });

    test('non-Map for object schema throws', () {
      expect(
        () => parser.parse(
          {'address': 'not_a_map'},
          {'address': RjObjectSchema({'city': RjTypeSchema<String>()})},
        ),
        throwsA(isA<RjParseException>()),
      );
    });

    test('non-List for list schema throws', () {
      expect(
        () => parser.parse(
          {'tags': 'not_a_list'},
          {'tags': RjListSchema(RjTypeSchema<String>())},
        ),
        throwsA(isA<RjParseException>()),
      );
    });
  });

  // ── Converter unit tests ───────────────────────────────────────────────────
  group('Converters — direct unit tests', () {
    test('rjCoerceInt from double', () =>
        expect(rjCoerceInt(3.9, 'x'), equals(3)));
    test('rjCoerceInt from bool true', () =>
        expect(rjCoerceInt(true, 'x'), equals(1)));
    test('rjCoerceDouble from int', () =>
        expect(rjCoerceDouble(5, 'x'), equals(5.0)));
    test('rjCoerceBool from "yes"', () =>
        expect(rjCoerceBool('yes', 'x'), isTrue));
    test('rjCoerceBool from "no"', () =>
        expect(rjCoerceBool('no', 'x'), isFalse));
    test('rjCoerceString from int', () =>
        expect(rjCoerceString(42, 'x'), equals('42')));
    test('rjCoerceString from bool', () =>
        expect(rjCoerceString(true, 'x'), equals('true')));
    test('rjCoerceUri from string', () {
      final u = rjCoerceUri('https://rj.dev', 'x');
      expect(u.host, equals('rj.dev'));
    });
    test('rjCoerceDateTime from seconds', () {
      final dt = rjCoerceDateTime(1712620800, 'x');
      expect(dt.year, equals(2024));
    });

    // Nullable variants
    test('rjCoerceIntNullable null → null', () =>
        expect(rjCoerceIntNullable(null, 'x'), isNull));
    test('rjCoerceStringNullable null → null', () =>
        expect(rjCoerceStringNullable(null, 'x'), isNull));

    // Error cases
    test('rjCoerceInt bad string throws', () =>
        expect(() => rjCoerceInt('abc', 'x'), throwsA(isA<RjParseException>())));
    test('rjCoerceBool bad string throws', () =>
        expect(() => rjCoerceBool('maybe', 'x'), throwsA(isA<RjParseException>())));
    test('rjCoerceDateTime bad string throws', () =>
        expect(
            () => rjCoerceDateTime('not-a-date', 'x'),
            throwsA(isA<RjParseException>())));
  });

  // ── RjParseResult ──────────────────────────────────────────────────────────
  group('RjParseResult', () {
    test('hasWarnings false when empty', () {
      final r = RjParseResult(data: {});
      expect(r.hasWarnings, isFalse);
    });

    test('hasWarnings true when non-empty', () {
      final r = RjParseResult(data: {}, warnings: ['oops']);
      expect(r.hasWarnings, isTrue);
    });
  });

  // ── RjParseException ───────────────────────────────────────────────────────
  group('RjParseException', () {
    test('toString includes fieldPath', () {
      final e = RjParseException('bad value', fieldPath: 'user.id');
      expect(e.toString(), contains('user.id'));
      expect(e.toString(), contains('bad value'));
    });

    test('toString without fieldPath', () {
      final e = RjParseException('bad value');
      expect(e.toString(), contains('bad value'));
      expect(e.toString(), isNot(contains('null')));
    });
  });
}
