/// Holds the coerced field values after a successful [RjSafeMapParser.parse]
/// call, plus any non-fatal warnings collected during parsing.
class RjParseResult {
  /// The fully coerced data map.
  /// Keys are field names; values have already been converted to their
  /// target Dart types.
  final Map<String, dynamic> data;

  /// Non-fatal issues collected during parsing
  /// (e.g. extra keys in non-strict mode).
  final List<String> warnings;

  const RjParseResult({required this.data, this.warnings = const []});

  bool get hasWarnings => warnings.isNotEmpty;

  @override
  String toString() =>
      'RjParseResult(keys: ${data.keys.toList()}, warnings: $warnings)';
}

/// Thrown when [RjSafeMapParser] encounters an unrecoverable error:
///   • A required field is missing or null
///   • A value cannot be coerced to the expected type
///   • An unknown key is present (in strict mode)
class RjParseException implements Exception {
  final String message;

  /// Dot-notation path to the offending field, e.g. `"address.zip"`.
  final String? fieldPath;

  const RjParseException(this.message, {this.fieldPath});

  @override
  String toString() => fieldPath != null
      ? 'RjParseException at "$fieldPath": $message'
      : 'RjParseException: $message';
}
