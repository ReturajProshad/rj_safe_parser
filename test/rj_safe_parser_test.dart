// test/rj_safe_parser_test.dart
//
// Full integration tests for the RJ Safe Parser runtime.
// Run with: dart test
//
// NOTE: Tests exercise the runtime engine directly —
// no build_runner or code generation required.

import 'package:test/test.dart';
import 'package:rj_safe_parser/rj_safe_parser.dart';

// ── Test enums ────────────────────────────────────────────────────────────────

enum Status { active, inactive, pending }

enum Priority { low, medium, high }

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Shared schema for most tests ──────────────────────────────────────────
  final schema = <String, RjFieldSchema>{
    'id': const RjTypeSchema<int>(typeName: 'int', jsonKey: 'id'),
    'name': const RjTypeSchema<String>(typeName: 'String', jsonKey: 'name'),
    'score': const RjTypeSchema<double>(typeName: 'double', jsonKey: 'score'),
    'isActive': const RjTypeSchema<bool>(typeName: 'bool', jsonKey: 'isActive'),
    'createdAt': const RjTypeSchema<DateTime>(
        typeName: 'DateTime', jsonKey: 'createdAt'),
    'profileUrl':
        const RjTypeSchema<Uri>(typeName: 'Uri', jsonKey: 'profileUrl'),
  };

  Map<String, dynamic> base({
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
    final parser = const RjSafeMapParser();

    test('int from numeric string', () {
      final r = parser.parse(base(id: '42'), schema);
      expect(r.data['id'], equals(42));
      expect(r.data['id'], isA<int>());
    });
    test('int from double', () {
      final r = parser.parse(base(id: 3.9), schema);
      expect(r.data['id'], equals(3));
    });
    test('double from string', () {
      final r = parser.parse(base(score: '3.14'), schema);
      expect(r.data['score'], closeTo(3.14, 0.0001));
    });
    test('double from int', () {
      final r = parser.parse(base(score: 5), schema);
      expect(r.data['score'], equals(5.0));
      expect(r.data['score'], isA<double>());
    });
    test('bool from int 1', () {
      expect(parser.parse(base(isActive: 1), schema).data['isActive'], isTrue);
    });
    test('bool from int 0', () {
      expect(parser.parse(base(isActive: 0), schema).data['isActive'], isFalse);
    });
    test('bool from string "true"', () {
      expect(parser.parse(base(isActive: 'true'), schema).data['isActive'],
          isTrue);
    });
    test('bool from string "false"', () {
      expect(parser.parse(base(isActive: 'false'), schema).data['isActive'],
          isFalse);
    });
    test('bool from string "yes"', () {
      expect(
          parser.parse(base(isActive: 'yes'), schema).data['isActive'], isTrue);
    });
    test('DateTime from Unix int (seconds)', () {
      final r = parser.parse(base(createdAt: 1712620800), schema);
      expect(r.data['createdAt'], isA<DateTime>());
      expect((r.data['createdAt'] as DateTime).year, equals(2024));
    });
    test('DateTime from Unix int (milliseconds)', () {
      expect(
        parser.parse(base(createdAt: 1712620800000), schema).data['createdAt'],
        isA<DateTime>(),
      );
    });
    test('DateTime from ISO-8601 string', () {
      final r = parser.parse(base(createdAt: '2024-04-09T00:00:00Z'), schema);
      expect((r.data['createdAt'] as DateTime).year, equals(2024));
    });
    test('Uri from string', () {
      final r = parser.parse(base(profileUrl: 'https://rj.dev/alice'), schema);
      expect((r.data['profileUrl'] as Uri).host, equals('rj.dev'));
    });
    test('String from int (toString coercion)', () {
      expect(parser.parse(base(name: 99), schema).data['name'], equals('99'));
    });
  });

  // ── Nullable fields ────────────────────────────────────────────────────────
  group('RjSafeMapParser — nullable fields', () {
    final nullableSchema = <String, RjFieldSchema>{
      'name': const RjTypeSchema<String?>(
        typeName: 'String',
        isNullable: true,
        jsonKey: 'name',
      ),
    };
    final parser = const RjSafeMapParser();

    test('absent nullable key → null', () {
      final r = parser.parse({}, nullableSchema);
      expect(r.data.containsKey('name'), isTrue);
      expect(r.data['name'], isNull);
    });
    test('explicit null nullable key → null', () {
      expect(parser.parse({'name': null}, nullableSchema).data['name'], isNull);
    });
  });

  // ── List fields ────────────────────────────────────────────────────────────
  group('RjSafeMapParser — list fields', () {
    final parser = const RjSafeMapParser();

    test('List<String> passes through', () {
      final s = {
        'tags': const RjListSchema(
          RjTypeSchema<String>(typeName: 'String', jsonKey: ''),
          jsonKey: 'tags',
        ),
      };
      expect(
        parser.parse({
          'tags': ['a', 'b', 'c']
        }, s).data['tags'],
        equals(['a', 'b', 'c']),
      );
    });
    test('required list with missing key throws', () {
      final s = {
        'tags': const RjListSchema(
          RjTypeSchema<String>(typeName: 'String', jsonKey: ''),
          jsonKey: 'tags',
        ),
      };
      expect(() => parser.parse({}, s), throwsA(isA<RjParseException>()));
    });
    test('nullable list with missing key returns empty', () {
      final s = {
        'tags': const RjListSchema(
          RjTypeSchema<String>(typeName: 'String', jsonKey: ''),
          isNullable: true,
          jsonKey: 'tags',
        ),
      };
      expect(parser.parse({}, s).data['tags'], isEmpty);
    });
    test('List<int> coerced from strings', () {
      final s = {
        'ids': const RjListSchema(
          RjTypeSchema<int>(typeName: 'int', jsonKey: ''),
          jsonKey: 'ids',
        ),
      };
      expect(
        parser.parse({
          'ids': ['1', '2', '3']
        }, s).data['ids'],
        equals([1, 2, 3]),
      );
    });
  });

  // ── Nested object ──────────────────────────────────────────────────────────
  group('RjSafeMapParser — nested objects', () {
    final parser = const RjSafeMapParser();
    final addressSchema = <String, RjFieldSchema>{
      'city': const RjTypeSchema<String>(typeName: 'String', jsonKey: 'city'),
      'zip': const RjTypeSchema<int>(typeName: 'int', jsonKey: 'zip'),
    };
    final userSchema = <String, RjFieldSchema>{
      'id': const RjTypeSchema<int>(typeName: 'int', jsonKey: 'id'),
      'address': RjObjectSchema(addressSchema, jsonKey: 'address'),
    };

    test('nested object parsed correctly', () {
      final r = parser.parse(
        {
          'id': 1,
          'address': {'city': 'Dhaka', 'zip': '1212'}
        },
        userSchema,
      );
      final addr = r.data['address'] as Map<String, dynamic>;
      expect(addr['city'], equals('Dhaka'));
      expect(addr['zip'], equals(1212));
    });
    test('nested zip coerced from string to int', () {
      final r = parser.parse(
        {
          'id': 1,
          'address': {'city': 'Chittagong', 'zip': '4000'}
        },
        userSchema,
      );
      expect((r.data['address'] as Map)['zip'], isA<int>());
    });
  });

  // ── Strict mode ────────────────────────────────────────────────────────────
  group('RjSafeMapParser — strict mode', () {
    final strict = const RjSafeMapParser(strict: true);
    final lenient = const RjSafeMapParser();

    test('unknown key throws in strict mode', () {
      expect(
        () => strict.parse(
          {'id': 1, 'extra': 'oops'},
          {'id': const RjTypeSchema<int>(typeName: 'int')},
        ),
        throwsA(isA<RjParseException>()),
      );
    });
    test('unknown key is warned in lenient mode', () {
      final r = lenient.parse(
        {'id': 1, 'extra': 'oops'},
        {'id': const RjTypeSchema<int>(typeName: 'int')},
      );
      expect(r.data['id'], equals(1));
      expect(r.hasWarnings, isTrue);
      expect(r.warnings.any((w) => w.contains('extra')), isTrue);
    });
  });

  // ── Error cases ────────────────────────────────────────────────────────────
  group('RjSafeMapParser — error cases', () {
    final parser = const RjSafeMapParser();

    test('null required int throws', () {
      expect(
        () => parser.parse(
            {'id': null}, {'id': const RjTypeSchema<int>(typeName: 'int')}),
        throwsA(isA<RjParseException>()),
      );
    });
    test('uncoercible string throws', () {
      expect(
        () => parser.parse(
          {'id': 'not_a_number'},
          {'id': const RjTypeSchema<int>(typeName: 'int', jsonKey: 'id')},
        ),
        throwsA(isA<RjParseException>()),
      );
    });
    test('non-Map for object schema throws', () {
      expect(
        () => parser.parse(
          {'address': 'not_a_map'},
          {
            'address': const RjObjectSchema(
              {
                'city':
                    RjTypeSchema<String>(typeName: 'String', jsonKey: 'city')
              },
              jsonKey: 'address',
            ),
          },
        ),
        throwsA(isA<RjParseException>()),
      );
    });
    test('non-List for list schema throws', () {
      expect(
        () => parser.parse(
          {'tags': 'not_a_list'},
          {
            'tags': const RjListSchema(
              RjTypeSchema<String>(typeName: 'String', jsonKey: ''),
              jsonKey: 'tags',
            ),
          },
        ),
        throwsA(isA<RjParseException>()),
      );
    });
    test('missing required list key throws', () {
      expect(
        () => parser.parse(
          {},
          {
            'tags': const RjListSchema(
              RjTypeSchema<String>(typeName: 'String', jsonKey: ''),
              jsonKey: 'tags',
            ),
          },
        ),
        throwsA(isA<RjParseException>()),
      );
    });
  });

  // ── Enum support ───────────────────────────────────────────────────────────
  group('RjSafeMapParser — enum by name', () {
    final parser = const RjSafeMapParser();
    final s = {
      'status': const RjEnumSchema(
        enumValues: Status.values,
        jsonKey: 'status',
      ),
    };

    test('string name → correct enum constant', () {
      expect(parser.parse({'status': 'active'}, s).data['status'],
          equals(Status.active));
      expect(parser.parse({'status': 'inactive'}, s).data['status'],
          equals(Status.inactive));
      expect(parser.parse({'status': 'pending'}, s).data['status'],
          equals(Status.pending));
    });
    test('unknown name throws RjParseException', () {
      expect(
        () => parser.parse({'status': 'unknown'}, s),
        throwsA(isA<RjParseException>()),
      );
    });
    test('null required enum throws', () {
      expect(
        () => parser.parse({'status': null}, s),
        throwsA(isA<RjParseException>()),
      );
    });
    test('missing required enum key throws', () {
      expect(() => parser.parse({}, s), throwsA(isA<RjParseException>()));
    });
    test('nullable enum — absent key → null', () {
      final ns = {
        'status': const RjEnumSchema(
          enumValues: Status.values,
          isNullable: true,
          jsonKey: 'status',
        ),
      };
      expect(parser.parse({}, ns).data['status'], isNull);
    });
    test('nullable enum — explicit null → null', () {
      final ns = {
        'status': const RjEnumSchema(
          enumValues: Status.values,
          isNullable: true,
          jsonKey: 'status',
        ),
      };
      expect(parser.parse({'status': null}, ns).data['status'], isNull);
    });
  });

  group('RjSafeMapParser — enum by index', () {
    final parser = const RjSafeMapParser();
    final s = {
      'priority': const RjEnumSchema(
        enumValues: Priority.values,
        byIndex: true,
        jsonKey: 'priority',
      ),
    };

    test('int index → correct enum constant', () {
      expect(parser.parse({'priority': 0}, s).data['priority'],
          equals(Priority.low));
      expect(parser.parse({'priority': 1}, s).data['priority'],
          equals(Priority.medium));
      expect(parser.parse({'priority': 2}, s).data['priority'],
          equals(Priority.high));
    });
    test('numeric string index → correct enum constant', () {
      expect(parser.parse({'priority': '2'}, s).data['priority'],
          equals(Priority.high));
    });
    test('out-of-range index throws', () {
      expect(
        () => parser.parse({'priority': 99}, s),
        throwsA(isA<RjParseException>()),
      );
    });
    test('non-numeric string throws', () {
      expect(
        () => parser.parse({'priority': 'high'}, s),
        throwsA(isA<RjParseException>()),
      );
    });
  });

  // ── Map<String, V> support ─────────────────────────────────────────────────
  group('RjSafeMapParser — Map<String, V>', () {
    final parser = const RjSafeMapParser();

    test('Map<String, String> passes through', () {
      final s = {
        'meta': const RjMapSchema(
          RjTypeSchema<String>(typeName: 'String'),
          jsonKey: 'meta',
        ),
      };
      final r = parser.parse(
        {
          'meta': {'lang': 'en', 'region': 'BD'}
        },
        s,
      );
      expect(r.data['meta'], equals({'lang': 'en', 'region': 'BD'}));
    });

    test('Map<String, int> coerced from string values', () {
      final s = {
        'scores': const RjMapSchema(
          RjTypeSchema<int>(typeName: 'int'),
          jsonKey: 'scores',
        ),
      };
      final r = parser.parse(
        {
          'scores': {'alice': '42', 'bob': '99'}
        },
        s,
      );
      final scores = r.data['scores'] as Map<String, dynamic>;
      expect(scores['alice'], equals(42));
      expect(scores['bob'], equals(99));
    });

    test('Map<String, bool> coerced from ints', () {
      final s = {
        'flags': const RjMapSchema(
          RjTypeSchema<bool>(typeName: 'bool'),
          jsonKey: 'flags',
        ),
      };
      final r = parser.parse(
        {
          'flags': {'featureA': 1, 'featureB': 0}
        },
        s,
      );
      final flags = r.data['flags'] as Map<String, dynamic>;
      expect(flags['featureA'], isTrue);
      expect(flags['featureB'], isFalse);
    });

    test('Map<String, double> coerced from string values', () {
      final s = {
        'rates': const RjMapSchema(
          RjTypeSchema<double>(typeName: 'double'),
          jsonKey: 'rates',
        ),
      };
      final r = parser.parse(
        {
          'rates': {'usd': '1.0', 'eur': '0.93'}
        },
        s,
      );
      final rates = r.data['rates'] as Map<String, dynamic>;
      expect(rates['eur'], closeTo(0.93, 0.0001));
    });

    test('missing required Map throws', () {
      final s = {
        'meta': const RjMapSchema(
          RjTypeSchema<String>(typeName: 'String'),
          jsonKey: 'meta',
        ),
      };
      expect(() => parser.parse({}, s), throwsA(isA<RjParseException>()));
    });

    test('nullable Map — absent key → null', () {
      final s = {
        'meta': const RjMapSchema(
          RjTypeSchema<String>(typeName: 'String'),
          isNullable: true,
          jsonKey: 'meta',
        ),
      };
      expect(parser.parse({}, s).data['meta'], isNull);
    });

    test('nullable Map — explicit null → null', () {
      final s = {
        'meta': const RjMapSchema(
          RjTypeSchema<String>(typeName: 'String'),
          isNullable: true,
          jsonKey: 'meta',
        ),
      };
      expect(parser.parse({'meta': null}, s).data['meta'], isNull);
    });

    test('non-Map value for Map schema throws', () {
      final s = {
        'meta': const RjMapSchema(
          RjTypeSchema<String>(typeName: 'String'),
          jsonKey: 'meta',
        ),
      };
      expect(
        () => parser.parse({'meta': 'not_a_map'}, s),
        throwsA(isA<RjParseException>()),
      );
    });

    test('Map with bad value throws with entry path', () {
      final s = {
        'scores': const RjMapSchema(
          RjTypeSchema<int>(typeName: 'int'),
          jsonKey: 'scores',
        ),
      };
      expect(
        () => parser.parse({
          'scores': {'alice': 'not_a_number'}
        }, s),
        throwsA(
          predicate<RjParseException>(
            (e) => e.fieldPath?.contains('alice') ?? false,
            'exception should contain entry key in fieldPath',
          ),
        ),
      );
    });

    test('empty map returns empty map', () {
      final s = {
        'meta': const RjMapSchema(
          RjTypeSchema<String>(typeName: 'String'),
          jsonKey: 'meta',
        ),
      };
      expect(parser.parse({'meta': {}}, s).data['meta'], isEmpty);
    });
  });

  // ── Converter unit tests ───────────────────────────────────────────────────
  group('Converters — direct unit tests', () {
    test('rjCoerceInt from double',
        () => expect(rjCoerceInt(3.9, 'x'), equals(3)));
    test('rjCoerceInt from bool',
        () => expect(rjCoerceInt(true, 'x'), equals(1)));
    test('rjCoerceDouble from int',
        () => expect(rjCoerceDouble(5, 'x'), equals(5.0)));
    test('rjCoerceBool from "yes"',
        () => expect(rjCoerceBool('yes', 'x'), isTrue));
    test('rjCoerceBool from "no"',
        () => expect(rjCoerceBool('no', 'x'), isFalse));
    test('rjCoerceString from int',
        () => expect(rjCoerceString(42, 'x'), equals('42')));
    test('rjCoerceString from bool',
        () => expect(rjCoerceString(true, 'x'), equals('true')));
    test('rjCoerceUri from string', () {
      expect(rjCoerceUri('https://rj.dev', 'x').host, equals('rj.dev'));
    });
    test('rjCoerceDateTime from seconds', () {
      expect(rjCoerceDateTime(1712620800, 'x').year, equals(2024));
    });
    test('rjCoerceIntNullable null → null',
        () => expect(rjCoerceIntNullable(null, 'x'), isNull));
    test('rjCoerceStringNullable null → null',
        () => expect(rjCoerceStringNullable(null, 'x'), isNull));
    test('rjCoerceInt bad string throws', () {
      expect(() => rjCoerceInt('abc', 'x'), throwsA(isA<RjParseException>()));
    });
    test('rjCoerceBool bad string throws', () {
      expect(
          () => rjCoerceBool('maybe', 'x'), throwsA(isA<RjParseException>()));
    });
    test('rjCoerceDateTime bad string throws', () {
      expect(() => rjCoerceDateTime('not-a-date', 'x'),
          throwsA(isA<RjParseException>()));
    });

    // Enum converters
    test('rjCoerceEnum by name — valid', () {
      expect(rjCoerceEnum('active', Status.values, 'x'), equals(Status.active));
    });
    test('rjCoerceEnum by name — invalid throws', () {
      expect(
        () => rjCoerceEnum('nope', Status.values, 'x'),
        throwsA(isA<RjParseException>()),
      );
    });
    test('rjCoerceEnum by index — valid', () {
      expect(rjCoerceEnum(1, Priority.values, 'x', byIndex: true),
          equals(Priority.medium));
    });
    test('rjCoerceEnum by index — string "2"', () {
      expect(rjCoerceEnum('2', Priority.values, 'x', byIndex: true),
          equals(Priority.high));
    });
    test('rjCoerceEnum by index — out of range throws', () {
      expect(
        () => rjCoerceEnum(99, Priority.values, 'x', byIndex: true),
        throwsA(isA<RjParseException>()),
      );
    });
    test('rjCoerceEnumNullable null → null', () {
      expect(rjCoerceEnumNullable(null, Status.values, 'x'), isNull);
    });

    // Map converters
    test('rjCoerceMap — string values', () {
      final result = rjCoerceMap(
        {'a': 'foo', 'b': 'bar'},
        'x',
        coerceValue: (v, _) => v.toString(),
      );
      expect(result, equals({'a': 'foo', 'b': 'bar'}));
    });
    test('rjCoerceMap — non-Map throws', () {
      expect(
        () => rjCoerceMap('not_a_map', 'x', coerceValue: (v, _) => v),
        throwsA(isA<RjParseException>()),
      );
    });
    test('rjCoerceMapNullable null → null', () {
      expect(
        rjCoerceMapNullable(null, 'x', coerceValue: (v, _) => v),
        isNull,
      );
    });
  });

  // ── RjParseResult ──────────────────────────────────────────────────────────
  group('RjParseResult', () {
    test('hasWarnings false when empty', () {
      expect(const RjParseResult(data: {}).hasWarnings, isFalse);
    });
    test('hasWarnings true when non-empty', () {
      expect(const RjParseResult(data: {}, warnings: ['oops']).hasWarnings,
          isTrue);
    });
  });

  // ── RjParseException ───────────────────────────────────────────────────────
  group('RjParseException', () {
    test('toString includes fieldPath', () {
      final e = const RjParseException('bad value', fieldPath: 'user.id');
      expect(e.toString(), contains('user.id'));
      expect(e.toString(), contains('bad value'));
    });
    test('toString without fieldPath', () {
      final e = const RjParseException('bad value');
      expect(e.toString(), contains('bad value'));
      expect(e.toString(), isNot(contains('null')));
    });
  });

  // ── @RjKey annotation ──────────────────────────────────────────────────────
  group('RjSafeMapParser — @RjKey mapping', () {
    final parser = const RjSafeMapParser();

    test('snake_case JSON key maps to camelCase field', () {
      final s = <String, RjFieldSchema>{
        'downloadUrl': const RjTypeSchema<String>(
          typeName: 'String',
          jsonKey: 'download_url',
        ),
      };
      final r =
          parser.parse({'download_url': 'https://example.com/img.jpg'}, s);
      expect(r.data['downloadUrl'], equals('https://example.com/img.jpg'));
    });
    test('multiple snake_case keys map correctly', () {
      final s = <String, RjFieldSchema>{
        'firstName': const RjTypeSchema<String>(
            typeName: 'String', jsonKey: 'first_name'),
        'lastName': const RjTypeSchema<String>(
            typeName: 'String', jsonKey: 'last_name'),
        'profileUrl': const RjTypeSchema<String>(
            typeName: 'String', jsonKey: 'profile_url'),
      };
      final r = parser.parse(
        {
          'first_name': 'Alice',
          'last_name': 'Smith',
          'profile_url': 'https://x.com'
        },
        s,
      );
      expect(r.data['firstName'], equals('Alice'));
      expect(r.data['lastName'], equals('Smith'));
    });
    test('missing JSON key throws for required field', () {
      final s = <String, RjFieldSchema>{
        'downloadUrl': const RjTypeSchema<String>(
          typeName: 'String',
          jsonKey: 'download_url',
        ),
      };
      expect(() => parser.parse({}, s), throwsA(isA<RjParseException>()));
    });
    test('nullable field with custom key accepts missing key', () {
      final s = <String, RjFieldSchema>{
        'nickname': const RjTypeSchema<String?>(
          typeName: 'String',
          isNullable: true,
          jsonKey: 'nick_name',
        ),
      };
      expect(parser.parse({}, s).data['nickname'], isNull);
    });
  });

  // ── Key-presence semantics ─────────────────────────────────────────────────
  group('RjSafeMapParser — key presence semantics', () {
    final parser = const RjSafeMapParser();

    test('absent required field throws', () {
      expect(
        () => parser.parse(
          {'name': 'Alice'},
          {
            'id': const RjTypeSchema<int>(typeName: 'int', jsonKey: 'id'),
            'name':
                const RjTypeSchema<String>(typeName: 'String', jsonKey: 'name'),
          },
        ),
        throwsA(isA<RjParseException>()),
      );
    });
    test('key present with null value throws for required field', () {
      expect(
        () => parser.parse(
          {'id': null},
          {'id': const RjTypeSchema<int>(typeName: 'int', jsonKey: 'id')},
        ),
        throwsA(isA<RjParseException>()),
      );
    });
    test('key absent for nullable field returns null', () {
      expect(
        parser.parse(
          {},
          {
            'nickname': const RjTypeSchema<String?>(
              typeName: 'String',
              isNullable: true,
              jsonKey: 'nickname',
            ),
          },
        ).data['nickname'],
        isNull,
      );
    });
  });
}
