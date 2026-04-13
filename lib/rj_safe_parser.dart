/// RJ Safe Parser
///
/// One annotation on the class. Zero per-field boilerplate.
///
/// Usage:
///   @RjSafeParsable()
///   class MyModel {
///     final int id;
///     final String name;
///     ...
///   }
///
/// Then run: dart run build_runner build
library rj_safe_parser;

export 'src/core/rj_annotation.dart';
export 'src/models/rj_schema.dart';
export 'src/parsers/rj_parser.dart';
export 'src/utils/rj_converters.dart';
export 'src/utils/rj_parse_result.dart';
