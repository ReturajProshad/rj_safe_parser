import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../../rj_safe_parser.dart';

/// Generates `fromMap()`, `toMap()`, and the schema constant for every
/// class annotated with `@RjSafeParsable()`.
class RjSafeParserGenerator extends GeneratorForAnnotation<RjSafeParsable> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@RjSafeParsable() can only be applied to classes.',
        element: element,
      );
    }

    final className = element.name;
    if (className == null) {
      throw InvalidGenerationSourceError('Class name is null.',
          element: element);
    }

    final strict = annotation.read('strict').boolValue;
    final dateFormatRaw = annotation.peek('dateFormat')?.stringValue;
    final dateFormatExpr = dateFormatRaw != null ? "'$dateFormatRaw'" : 'null';

    final fields = element.fields.where((f) {
      final name = f.name;
      return !f.isStatic && !f.isSynthetic && name != null && name.isNotEmpty && !name.startsWith('_');
    }).toList();

    final fieldJsonKeys = <FieldElement, String>{};
    for (final field in fields) {
      fieldJsonKeys[field] = _extractJsonKey(field);
    }

    final buf = StringBuffer();

    _writeFromMap(
        buf, className, fields, fieldJsonKeys, strict, dateFormatExpr);
    _writeToMap(buf, className, fields, fieldJsonKeys);
    _writeSchema(buf, className, fields, fieldJsonKeys);

    return buf.toString();
  }

  // ── Annotation helpers ─────────────────────────────────────────────────────

  String _extractJsonKey(FieldElement field) {
    final fieldName = field.name;
    if (fieldName == null) return '';

    for (final annotation in field.metadata.annotations) {
      final el = annotation.element;
      if (el != null && el.displayName == 'RjKey') {
        final constant = annotation.computeConstantValue();
        if (constant != null) {
          final snakeCase =
              constant.getField('snakeCase')?.toBoolValue() ?? false;
          if (snakeCase) return _toSnakeCase(fieldName);
          final jsonKey = constant.getField('jsonKey')?.toStringValue();
          if (jsonKey != null && jsonKey.isNotEmpty) return jsonKey;
        }
      }
    }
    return fieldName;
  }

  /// Returns true if the field has @RjEnum and byIndex: true.
  bool _enumByIndex(FieldElement field) {
    for (final annotation in field.metadata.annotations) {
      final el = annotation.element;
      if (el != null && el.displayName == 'RjEnum') {
        final constant = annotation.computeConstantValue();
        if (constant != null) {
          return constant.getField('byIndex')?.toBoolValue() ?? false;
        }
      }
    }
    return false;
  }

  String _toSnakeCase(String camelCase) {
    final buf = StringBuffer();
    for (var i = 0; i < camelCase.length; i++) {
      final char = camelCase[i];
      if (char == char.toUpperCase() && char != char.toLowerCase()) {
        if (i > 0) buf.write('_');
        buf.write(char.toLowerCase());
      } else {
        buf.write(char);
      }
    }
    return buf.toString();
  }

  // ── fromMap ────────────────────────────────────────────────────────────────

  void _writeFromMap(
    StringBuffer buf,
    String className,
    List<FieldElement> fields,
    Map<FieldElement, String> fieldJsonKeys,
    bool strict,
    String dateFormatExpr,
  ) {
    buf
      ..writeln('$className _\$${className}FromMap(Map<String, dynamic> map) {')
      ..writeln(
          '  final parser = const RjSafeMapParser(strict: $strict, dateFormat: $dateFormatExpr);')
      ..writeln('  final result = parser.parse(map, _\$${className}Schema);')
      ..writeln('  return $className(');

    for (final field in fields) {
      final jsonKey = fieldJsonKeys[field]!;
      buf.writeln(
          '    ${field.name}: ${_castExpression(field, field.type, jsonKey)},');
    }

    buf
      ..writeln('  );')
      ..writeln('}')
      ..writeln();
  }

  // ── toMap ──────────────────────────────────────────────────────────────────

  void _writeToMap(
    StringBuffer buf,
    String className,
    List<FieldElement> fields,
    Map<FieldElement, String> fieldJsonKeys,
  ) {
    buf
      ..writeln(
          'Map<String, dynamic> _\$${className}ToMap($className instance) {')
      ..writeln('  return {');

    for (final field in fields) {
      final jsonKey = fieldJsonKeys[field]!;
      final expr =
          _serializeExpression(field, field.type, 'instance.${field.name}');
      buf.writeln("    '$jsonKey': $expr,");
    }

    buf
      ..writeln('  };')
      ..writeln('}')
      ..writeln();
  }

  // ── Schema constant ────────────────────────────────────────────────────────

  void _writeSchema(
    StringBuffer buf,
    String className,
    List<FieldElement> fields,
    Map<FieldElement, String> fieldJsonKeys,
  ) {
    buf.writeln('final Map<String, RjFieldSchema> _\$${className}Schema = {');

    for (final field in fields) {
      final jsonKey = fieldJsonKeys[field]!;
      buf.writeln(
          "  '${field.name}': ${_schemaExpression(field, field.type, jsonKey)},");
    }

    buf
      ..writeln('};')
      ..writeln();
  }

  // ── Schema expression ──────────────────────────────────────────────────────

  String _schemaExpression(FieldElement? field, DartType type, String jsonKey) {
    final nullable = _isNullable(type);
    final inner = _unwrap(type);
    final nullableStr = nullable ? 'true' : 'false';

    // ── Primitives ────────────────────────────────────────────────────────────
    if (_isCore(inner, 'String')) {
      return "const RjTypeSchema<String>(typeName: 'String', isNullable: $nullableStr, jsonKey: '$jsonKey')";
    }
    if (_isCore(inner, 'int')) {
      return "const RjTypeSchema<int>(typeName: 'int', isNullable: $nullableStr, jsonKey: '$jsonKey')";
    }
    if (_isCore(inner, 'double')) {
      return "const RjTypeSchema<double>(typeName: 'double', isNullable: $nullableStr, jsonKey: '$jsonKey')";
    }
    if (_isCore(inner, 'bool')) {
      return "const RjTypeSchema<bool>(typeName: 'bool', isNullable: $nullableStr, jsonKey: '$jsonKey')";
    }
    if (_isCore(inner, 'DateTime')) {
      return "const RjTypeSchema<DateTime>(typeName: 'DateTime', isNullable: $nullableStr, jsonKey: '$jsonKey')";
    }
    if (_isCore(inner, 'Uri')) {
      return "const RjTypeSchema<Uri>(typeName: 'Uri', isNullable: $nullableStr, jsonKey: '$jsonKey')";
    }

    // ── Enum ──────────────────────────────────────────────────────────────────
    if (inner is InterfaceType && inner.element is EnumElement) {
      final enumName = inner.element.name;
      final byIndex = field != null ? _enumByIndex(field) : false;
      return "RjEnumSchema(enumValues: $enumName.values, byIndex: $byIndex, "
          "isNullable: $nullableStr, jsonKey: '$jsonKey')";
    }

    // ── Map<String, V> ────────────────────────────────────────────────────────
    if (inner is InterfaceType && inner.element.name == 'Map') {
      // We only support Map<String, V> — enforce String key at codegen time.
      final keyType = inner.typeArguments[0];
      if (!_isCore(_unwrap(keyType), 'String')) {
        throw InvalidGenerationSourceError(
          'Only Map<String, V> is supported. '
          'Got Map<$keyType, ...> on field "${field?.name ?? '?'}".',
        );
      }
      final valueType = inner.typeArguments[1];
      final valueSchema = _schemaExpression(null, valueType, '');
      return "RjMapSchema($valueSchema, isNullable: $nullableStr, jsonKey: '$jsonKey')";
    }

    // ── List<T> ───────────────────────────────────────────────────────────────
    if (inner is InterfaceType && inner.element.name == 'List') {
      final itemSchema = _schemaExpression(null, inner.typeArguments.first, '');
      return "const RjListSchema($itemSchema, isNullable: $nullableStr, jsonKey: '$jsonKey')";
    }

    // ── Nested @RjSafeParsable ────────────────────────────────────────────────
    if (inner is InterfaceType && _hasRjAnnotation(inner)) {
      return _inlineObjectSchema(
          inner.element as ClassElement, jsonKey, nullable);
    }

    throw InvalidGenerationSourceError(
      'Unsupported field type: $type. '
      'Annotate the nested class with @RjSafeParsable(), or use '
      'Map<String, V> for dynamic maps.',
    );
  }

  /// Recursively builds an `RjObjectSchema({...})` literal inline.
  String _inlineObjectSchema(
      ClassElement classElement, String jsonKey, bool nullable) {
    final fields = classElement.fields.where((f) {
      final name = f.name;
      return !f.isStatic && !f.isSynthetic && name != null && name.isNotEmpty && !name.startsWith('_');
    }).toList();

    final entries = fields
        .map((f) =>
            "'${f.name}': ${_schemaExpression(f, f.type, _extractJsonKey(f))}")
        .join(',\n    ');

    final nullableStr = nullable ? 'true' : 'false';
    return "const RjObjectSchema({\n    $entries,\n  }, isNullable: $nullableStr, jsonKey: '$jsonKey')";
  }

  // ── Cast expression (fromMap body) ────────────────────────────────────────

  String _castExpression(FieldElement field, DartType type, String jsonKey) {
    final nullable = _isNullable(type);
    final inner = _unwrap(type);
    final q = nullable ? '?' : '';

    // Enum — cast to the concrete enum type
    if (inner is InterfaceType && inner.element is EnumElement) {
      final enumName = inner.element.name;
      return "result.data['$jsonKey'] as $enumName$q";
    }

    // Map<String, V> — cast to Map then re-cast values if needed
    if (inner is InterfaceType && inner.element.name == 'Map') {
      final valueType = _unwrap(inner.typeArguments[1]);
      final valueName = _typeName(valueType);
      if (nullable) {
        return "(result.data['$jsonKey'] as Map<String, dynamic>?)?.cast<String, $valueName>()";
      }
      return "(result.data['$jsonKey'] as Map<String, dynamic>).cast<String, $valueName>()";
    }

    // Primitives
    if (_isPrimitive(inner)) {
      return "result.data['$jsonKey'] as ${_typeName(inner)}$q";
    }

    // List<T>
    if (inner is InterfaceType && inner.element.name == 'List') {
      final itemType = inner.typeArguments.first;
      final itemInner = _unwrap(itemType);

      if (itemInner is InterfaceType && itemInner.element is EnumElement) {
        final enumName = itemInner.element.name;
        return "(result.data['$jsonKey'] as List$q)"
            "$q.map((e) => e as $enumName).toList()"
            "${nullable ? ' ?? []' : ''}";
      }

      if (_hasRjAnnotation(itemInner)) {
        final itemClass = (itemInner as InterfaceType).element.name;
        return "(result.data['$jsonKey'] as List$q)"
            "$q.map((e) => $itemClass.fromMap(e as Map<String, dynamic>)).toList()"
            "${nullable ? ' ?? []' : ''}";
      }

      final itemName = _typeName(itemInner);
      return "(result.data['$jsonKey'] as List$q)"
          "$q.cast<$itemName>()"
          "${nullable ? ' ?? []' : ''}";
    }

    // Nested @RjSafeParsable object
    if (inner is InterfaceType && _hasRjAnnotation(inner)) {
      final cls = inner.element.name;
      if (nullable) {
        return "result.data['$jsonKey'] != null "
            "? $cls.fromMap(result.data['$jsonKey'] as Map<String, dynamic>) "
            ": null";
      }
      return "$cls.fromMap(result.data['$jsonKey'] as Map<String, dynamic>)";
    }

    return nullable ? "result.data['$jsonKey']" : "result.data['$jsonKey']!";
  }

  // ── Serialize expression (toMap body) ─────────────────────────────────────

  String _serializeExpression(
      FieldElement field, DartType type, String accessor) {
    final inner = _unwrap(type);
    final nullable = _isNullable(type);
    final q = nullable ? '?' : '';

    if (_isCore(inner, 'DateTime')) return '$accessor$q.toIso8601String()';
    if (_isCore(inner, 'Uri')) return '$accessor$q.toString()';

    // Enum — serialize to name (default) or index (byIndex: true)
    if (inner is InterfaceType && inner.element is EnumElement) {
      final byIndex = _enumByIndex(field);
      if (byIndex) {
        return '$accessor$q.index';
      }
      return '$accessor$q.name';
    }

    // Map<String, V> — serialize values
    if (inner is InterfaceType && inner.element.name == 'Map') {
      final valueInner = _unwrap(inner.typeArguments[1]);
      if (_hasRjAnnotation(valueInner)) {
        return '$accessor$q.map((k, v) => MapEntry(k, v.toMap()))';
      }
      if (_isCore(valueInner, 'DateTime')) {
        return '$accessor$q.map((k, v) => MapEntry(k, v.toIso8601String()))';
      }
      if (_isCore(valueInner, 'Uri')) {
        return '$accessor$q.map((k, v) => MapEntry(k, v.toString()))';
      }
      return accessor;
    }

    // List
    if (inner is InterfaceType && inner.element.name == 'List') {
      final itemInner = _unwrap(inner.typeArguments.first);
      if (_hasRjAnnotation(itemInner)) {
        return '$accessor$q.map((e) => e.toMap()).toList()';
      }
      return accessor;
    }

    // Nested object
    if (inner is InterfaceType && _hasRjAnnotation(inner)) {
      return '$accessor$q.toMap()';
    }

    return accessor;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  DartType _unwrap(DartType type) => type;

  bool _isNullable(DartType type) =>
      type.nullabilitySuffix == NullabilitySuffix.question;

  bool _isCore(DartType type, String name) =>
      type is InterfaceType && type.element.name == name;

  bool _isPrimitive(DartType type) => const [
        'String',
        'int',
        'double',
        'bool',
        'DateTime',
        'Uri'
      ].any((n) => _isCore(type, n));

  String _typeName(DartType type) {
    if (type is InterfaceType) return type.element.name ?? '';
    return type.toString().replaceAll('?', '');
  }

  bool _hasRjAnnotation(DartType type) {
    if (type is! InterfaceType) return false;
    for (final annotation in type.element.metadata.annotations) {
      if (annotation.element?.displayName == 'RjSafeParsable') return true;
    }
    return false;
  }
}
