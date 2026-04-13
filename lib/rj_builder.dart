library rj_safe_parser_builder;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/generator/rj_safe_parser_generator.dart';

/// Entry point registered in build.yaml.
/// Run: dart run build_runner build
Builder rjSafeParserBuilder(BuilderOptions options) =>
    SharedPartBuilder([RjSafeParserGenerator()], 'rj_safe_parser');
