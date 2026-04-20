/// The only annotation you ever need — placed **once** on the class.
/// No per-field decoration required.
///
/// build_runner reads your Dart field types automatically and generates:
///   • `_$ClassFromMap(Map<String, dynamic>)`  ← safe, coercing parser
///   • `_$ClassToMap(instance)`                ← serializer
///   • `_$ClassSchema`                         ← schema constant
///
/// Example:
/// ```dart
/// import 'package:rj_safe_parser/rj_safe_parser.dart';
/// part 'my_model.g.dart';
///
/// @RjSafeParsable()
/// class MyModel {
///   final int id;
///   final String name;
///   final String? nickname;   // nullable → field is optional
///   final DateTime createdAt;
///   final AddressModel address; // nested @RjSafeParsable class
///   ...
///
///   factory MyModel.fromMap(Map<String, dynamic> map) => _$MyModelFromMap(map);
///   Map<String, dynamic> toMap() => _$MyModelToMap(this);
/// }
/// ```
class RjSafeParsable {
  /// `false` (default) — unknown keys in the source map are silently ignored.
  /// `true`            — unknown keys throw [RjParseException].
  final bool strict;

  /// Optional date format for [DateTime] fields (e.g. `'yyyy-MM-dd'`).
  /// When null, ISO-8601 strings and Unix int/double timestamps are both accepted.
  final String? dateFormat;

  const RjSafeParsable({this.strict = false, this.dateFormat});
}

/// Annotate individual fields to specify the JSON key name.
/// Use this when the JSON key differs from the Dart field name
/// (e.g., snake_case JSON → camelCase Dart).
///
/// Example:
/// ```dart
/// @RjSafeParsable()
/// class Photo {
///   final String id;
///   final String author;
///
///   @RjKey('download_url')
///   final String downloadUrl;
///
///   Photo({required this.id, required this.author, required this.downloadUrl});
///
///   factory Photo.fromMap(Map<String, dynamic> map) => _$PhotoFromMap(map);
///   Map<String, dynamic> toMap() => _$PhotoToMap(this);
/// }
/// ```
///
/// The generated code will:
///   • Read from JSON key `'download_url'`
///   • Store in Dart field `downloadUrl`
///   • Serialize back to `'download_url'` in `toMap()`
class RjKey {
  /// The exact key name as it appears in the JSON.
  final String jsonKey;

  /// Optional: if true, use snake_case conversion from field name.
  /// Mutually exclusive with [jsonKey].
  final bool snakeCase;

  const RjKey(this.jsonKey, {this.snakeCase = false});

  /// Convenience constructor for automatic snake_case conversion.
  /// Field `downloadUrl` → JSON key `download_url`
  const RjKey.snakeCase() : this('', snakeCase: true);
}
