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

    final buf = StringBuffer();
    // source_gen adds the "GENERATED CODE" header automatically.

    _writeFromMap(buf, className, fields, strict, dateFormatExpr);
    _writeToMap(buf, className, fields);
    _writeSchema(buf, className, fields);

    return buf.toString();
  }

  // ── fromMap ────────────────────────────────────────────────────────────────

  void _writeFromMap(
    StringBuffer buf,
    String className,
    List<FieldElement> fields,
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
      buf.writeln(
          '    ${field.name}: ${_castExpression(field.type, field.name)},');
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
  ) {
    buf
      ..writeln(
          'Map<String, dynamic> _\$${className}ToMap($className instance) {')
      ..writeln('  return {');

    for (final field in fields) {
      final expr = _serializeExpression(field.type, 'instance.${field.name}');
      buf.writeln("    '${field.name}': $expr,");
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
  ) {
    buf.writeln('final Map<String, RjFieldSchema> _\$${className}Schema = {');

    for (final field in fields) {
      buf.writeln("  '${field.name}': ${_schemaExpression(field.type)},");
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

  String _schemaExpression(DartType type) {
    final inner = _unwrap(type);

    if (_isCore(inner, 'String')) return 'const RjTypeSchema<String>()';
    if (_isCore(inner, 'int')) return 'const RjTypeSchema<int>()';
    if (_isCore(inner, 'double')) return 'const RjTypeSchema<double>()';
    if (_isCore(inner, 'bool')) return 'const RjTypeSchema<bool>()';
    if (_isCore(inner, 'DateTime')) return 'const RjTypeSchema<DateTime>()';
    if (_isCore(inner, 'Uri')) return 'const RjTypeSchema<Uri>()';

    if (inner is InterfaceType && inner.element.name == 'List') {
      final itemSchema = _schemaExpression(inner.typeArguments.first);
      return 'const RjListSchema($itemSchema)';
    }

    if (inner is InterfaceType && _hasRjAnnotation(inner)) {
      // Build the nested schema inline instead of referencing _$NestedSchema
      // (which would be a cross-part reference — undefined at compile time).
      return _inlineObjectSchema(inner.element as ClassElement);
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
  String _inlineObjectSchema(ClassElement classElement) {
    final fields = classElement.fields
        .where((f) => !f.isStatic && !f.isSynthetic && !f.name.startsWith('_'))
        .toList();

    final entries = fields
        .map((f) => "'${f.name}': ${_schemaExpression(f.type)}")
        .join(',\n    ');

    return 'const RjObjectSchema({\n    $entries,\n  })';
  }

  // ── Cast expression (fromMap body) ────────────────────────────────────────

  String _castExpression(DartType type, String fieldName) {
    final nullable = _isNullable(type);
    final inner = _unwrap(type);
    final q = nullable ? '?' : '';

    // Primitives — already coerced by RjSafeMapParser, just cast
    if (_isPrimitive(inner)) {
      return "result.data['$fieldName'] as ${_typeName(inner)}$q";
    }

    // List<T>
    if (inner is InterfaceType && inner.element.name == 'List') {
      final itemType = inner.typeArguments.first;
      final itemInner = _unwrap(itemType);

      if (_hasRjAnnotation(itemInner)) {
        final itemClass = (itemInner as InterfaceType).element.name;
        return "(result.data['$fieldName'] as List$q)"
            "$q.map((e) => $itemClass.fromMap(e as Map<String, dynamic>)).toList()"
            "${nullable ? ' ?? []' : ''}";
      }

      final itemName = _typeName(itemInner);
      return "(result.data['$fieldName'] as List$q)"
          "$q.cast<$itemName>()"
          "${nullable ? ' ?? []' : ''}";
    }

    // Nested @RjSafeParsable object — delegate to its own fromMap()
    if (inner is InterfaceType && _hasRjAnnotation(inner)) {
      final cls = inner.element.name;
      if (nullable) {
        return "result.data['$fieldName'] != null "
            "? $cls.fromMap(result.data['$fieldName'] as Map<String, dynamic>) "
            ": null";
      }
      return "$cls.fromMap(result.data['$fieldName'] as Map<String, dynamic>)";
    }

    return nullable
        ? "result.data['$fieldName']"
        : "result.data['$fieldName']!";
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
