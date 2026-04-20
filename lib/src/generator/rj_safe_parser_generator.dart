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
    final strict = annotation.read('strict').boolValue;
    final dateFormatRaw = annotation.peek('dateFormat')?.stringValue;
    final dateFormatExpr = dateFormatRaw != null ? "'$dateFormatRaw'" : 'null';

    final fields = element.fields
        .where((f) => !f.isStatic && !f.isSynthetic && !f.name.startsWith('_'))
        .toList();

    final fieldJsonKeys = <FieldElement, String>{};
    for (final field in fields) {
      fieldJsonKeys[field] = _extractJsonKey(field);
    }

    final buf = StringBuffer();
    // source_gen adds the "GENERATED CODE" header automatically.

    _writeFromMap(buf, className, fields, fieldJsonKeys, strict, dateFormatExpr);
    _writeToMap(buf, className, fields, fieldJsonKeys);
    _writeSchema(buf, className, fields, fieldJsonKeys);

    return buf.toString();
  }

  String _extractJsonKey(FieldElement field) {
    for (final annotation in field.metadata) {
      final element = annotation.element;
      if (element != null && element.displayName == 'RjKey') {
        final constant = annotation.computeConstantValue();
        if (constant != null) {
          final snakeCase = constant.getField('snakeCase')?.toBoolValue() ?? false;
          if (snakeCase) {
            return _toSnakeCase(field.name);
          }
          final jsonKey = constant.getField('jsonKey')?.toStringValue();
          if (jsonKey != null && jsonKey.isNotEmpty) {
            return jsonKey;
          }
        }
      }
    }
    return field.name;
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
          '    ${field.name}: ${_castExpression(field.type, jsonKey)},');
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
      final expr = _serializeExpression(field.type, 'instance.${field.name}');
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
      buf.writeln("  '${field.name}': ${_schemaExpression(field.type, jsonKey)},");
    }

    buf
      ..writeln('};')
      ..writeln();
  }

  // ── Schema expression ──────────────────────────────────────────────────────
  //
  // KEY FIX: nested @RjSafeParsable classes must NOT reference
  // `_$NestedClassSchema` — that symbol lives in a different part file and
  // is invisible here. Instead, build the RjObjectSchema inline by reading
  // the nested class's fields directly from the analyzer element.

  String _schemaExpression(DartType type, String jsonKey) {
    final inner = _unwrap(type);

    if (_isCore(inner, 'String')) return 'const RjTypeSchema<String>(jsonKey: \'$jsonKey\')';
    if (_isCore(inner, 'int')) return 'const RjTypeSchema<int>(jsonKey: \'$jsonKey\')';
    if (_isCore(inner, 'double')) return 'const RjTypeSchema<double>(jsonKey: \'$jsonKey\')';
    if (_isCore(inner, 'bool')) return 'const RjTypeSchema<bool>(jsonKey: \'$jsonKey\')';
    if (_isCore(inner, 'DateTime')) return 'const RjTypeSchema<DateTime>(jsonKey: \'$jsonKey\')';
    if (_isCore(inner, 'Uri')) return 'const RjTypeSchema<Uri>(jsonKey: \'$jsonKey\')';

    if (inner is InterfaceType && inner.element.name == 'List') {
      final itemSchema = _schemaExpression(inner.typeArguments.first, '');
      return 'const RjListSchema($itemSchema, jsonKey: \'$jsonKey\')';
    }

    if (inner is InterfaceType && _hasRjAnnotation(inner)) {
      // Build the nested schema inline instead of referencing _$NestedSchema
      // (which would be a cross-part `_$NestedSchema` reference — undefined at compile time).
      return _inlineObjectSchema(inner.element as ClassElement, jsonKey);
    }

    throw InvalidGenerationSourceError(
      'Unsupported field type: $type. '
      'Annotate the nested class with @RjSafeParsable() or '
      'register a custom converter.',
    );
  }

  /// Recursively builds an `RjObjectSchema({...})` literal inline,
  /// walking the nested class's fields via the analyzer element.
  /// This avoids any cross-part `_$NestedSchema` reference.
  String _inlineObjectSchema(ClassElement classElement, String jsonKey) {
    final fields = classElement.fields
        .where((f) => !f.isStatic && !f.isSynthetic && !f.name.startsWith('_'))
        .toList();

    final entries = fields
        .map((f) => "'${f.name}': ${_schemaExpression(f.type, '')}")
        .join(',\n    ');

    return 'const RjObjectSchema({\n    $entries,\n  }, jsonKey: \'$jsonKey\')';
  }

  // ── Cast expression (fromMap body) ────────────────────────────────────────

  String _castExpression(DartType type, String jsonKey) {
    final nullable = _isNullable(type);
    final inner = _unwrap(type);
    final q = nullable ? '?' : '';

    // Primitives — already coerced by RjSafeMapParser, just cast
    if (_isPrimitive(inner)) {
      return "result.data['$jsonKey'] as ${_typeName(inner)}$q";
    }

    // List<T>
    if (inner is InterfaceType && inner.element.name == 'List') {
      final itemType = inner.typeArguments.first;
      final itemInner = _unwrap(itemType);

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

    // Nested @RjSafeParsable object — delegate to its own fromMap()
    if (inner is InterfaceType && _hasRjAnnotation(inner)) {
      final cls = inner.element.name;
      if (nullable) {
        return "result.data['$jsonKey'] != null "
            "? $cls.fromMap(result.data['$jsonKey'] as Map<String, dynamic>) "
            ": null";
      }
      return "$cls.fromMap(result.data['$jsonKey'] as Map<String, dynamic>)";
    }

    return nullable
        ? "result.data['$jsonKey']"
        : "result.data['$jsonKey']!";
  }

  // ── Serialize expression (toMap body) ─────────────────────────────────────

  String _serializeExpression(DartType type, String accessor) {
    final inner = _unwrap(type);
    final nullable = _isNullable(type);
    final q = nullable ? '?' : '';

    if (_isCore(inner, 'DateTime')) return '$accessor$q.toIso8601String()';
    if (_isCore(inner, 'Uri')) return '$accessor$q.toString()';

    if (inner is InterfaceType && inner.element.name == 'List') {
      final itemInner = _unwrap(inner.typeArguments.first);
      if (_hasRjAnnotation(itemInner)) {
        return '$accessor$q.map((e) => e.toMap()).toList()';
      }
      return accessor;
    }

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
        'Uri',
      ].any((n) => _isCore(type, n));

  String _typeName(DartType type) {
    if (type is InterfaceType) return type.element.name;
    return type.toString().replaceAll('?', '');
  }

  bool _hasRjAnnotation(DartType type) {
    if (type is! InterfaceType) return false;
    return type.element.metadata.any(
      (m) => m.element?.displayName == 'RjSafeParsable',
    );
  }
}
