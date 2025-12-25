import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'src/registry_generator.dart';

/// Builder for generating network job registry code.
/// This name must match the builder_factories in build.yaml.
Builder networkRegistryBuilder(BuilderOptions options) =>
    SharedPartBuilder([NetworkRegistryGenerator()], 'network_registry');
