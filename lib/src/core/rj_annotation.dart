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
