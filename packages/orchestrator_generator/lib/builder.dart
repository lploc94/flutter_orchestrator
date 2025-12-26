import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'src/registry_generator.dart';
import 'src/generators/network_job_generator.dart';
import 'src/generators/executor_registry_generator.dart';
import 'src/generators/orchestrator_generator.dart';
import 'src/generators/async_state_generator.dart';
import 'src/generators/job_event_generator.dart';

/// Builder for generating network job registry code.
/// This name must match the builder_factories in build.yaml.
Builder networkRegistryBuilder(BuilderOptions options) =>
    SharedPartBuilder([NetworkRegistryGenerator()], 'network_registry');

Builder networkJobBuilder(BuilderOptions options) =>
    SharedPartBuilder([NetworkJobGenerator()], 'network_job');

Builder executorRegistryBuilder(BuilderOptions options) =>
    SharedPartBuilder([ExecutorRegistryGenerator()], 'executor_registry');

Builder orchestratorBuilder(BuilderOptions options) =>
    SharedPartBuilder([OrchestratorGenerator()], 'orchestrator');

Builder asyncStateBuilder(BuilderOptions options) =>
    SharedPartBuilder([AsyncStateGenerator()], 'async_state');

Builder jobBuilder(BuilderOptions options) =>
    SharedPartBuilder([JobGenerator()], 'job');

Builder eventBuilder(BuilderOptions options) =>
    SharedPartBuilder([EventGenerator()], 'event');
