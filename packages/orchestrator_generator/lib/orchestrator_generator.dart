/// Configuration for Builders used in `build.yaml`.
///
/// Use strict versions of these builders to generate code.
library orchestrator_generator;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'src/registry_generator.dart';
import 'src/generators/network_job_generator.dart';
import 'src/generators/executor_registry_generator.dart';
import 'src/generators/orchestrator_generator.dart';
import 'src/generators/async_state_generator.dart';
import 'src/generators/job_event_generator.dart';
import 'src/generators/typed_job_generator.dart';
import 'src/generators/orchestrator_provider_generator.dart';

/// Builder for generating network job registry code.
/// This name must match the builder_factories in build.yaml.
Builder networkRegistryBuilder(BuilderOptions options) =>
    SharedPartBuilder([NetworkRegistryGenerator()], 'network_registry');

/// Builder for generating network job extension methods.
Builder networkJobBuilder(BuilderOptions options) =>
    SharedPartBuilder([NetworkJobGenerator()], 'network_job');

/// Builder for generating executor registry code.
Builder executorRegistryBuilder(BuilderOptions options) =>
    SharedPartBuilder([ExecutorRegistryGenerator()], 'executor_registry');

/// Builder for generating orchestrator event routing code.
Builder orchestratorBuilder(BuilderOptions options) =>
    SharedPartBuilder([OrchestratorGenerator()], 'orchestrator');

/// Builder for generating async state pattern matching and copyWith methods.
Builder asyncStateBuilder(BuilderOptions options) =>
    SharedPartBuilder([AsyncStateGenerator()], 'async_state');

/// Builder for generating job boilerplate code.
Builder jobBuilder(BuilderOptions options) =>
    SharedPartBuilder([JobGenerator()], 'job');

/// Builder for generating event boilerplate code.
Builder eventBuilder(BuilderOptions options) =>
    SharedPartBuilder([EventGenerator()], 'event');

/// Builder for generating typed job hierarchies from interface classes.
Builder typedJobBuilder(BuilderOptions options) =>
    SharedPartBuilder([TypedJobGenerator()], 'typed_job');

/// Builder for generating Riverpod providers for orchestrators.
Builder orchestratorProviderBuilder(BuilderOptions options) =>
    SharedPartBuilder([OrchestratorProviderGenerator()], 'orchestrator_provider');
