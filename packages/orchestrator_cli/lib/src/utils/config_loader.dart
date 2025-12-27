import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Configuration for Orchestrator CLI
class OrchestratorConfig {
  /// Default state management solution
  final String stateManagement;

  /// Output paths
  final OutputConfig output;

  /// Feature scaffold settings
  final FeatureConfig feature;

  const OrchestratorConfig({
    this.stateManagement = 'cubit',
    this.output = const OutputConfig(),
    this.feature = const FeatureConfig(),
  });

  factory OrchestratorConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return OrchestratorConfig(
      stateManagement: yaml['state_management'] as String? ?? 'cubit',
      output: yaml['output'] != null
          ? OutputConfig.fromYaml(yaml['output'] as Map<dynamic, dynamic>)
          : const OutputConfig(),
      feature: yaml['feature'] != null
          ? FeatureConfig.fromYaml(yaml['feature'] as Map<dynamic, dynamic>)
          : const FeatureConfig(),
    );
  }
}

/// Output path configuration
class OutputConfig {
  final String features;
  final String jobs;
  final String executors;

  const OutputConfig({
    this.features = 'lib/features',
    this.jobs = 'lib/core/jobs',
    this.executors = 'lib/core/executors',
  });

  factory OutputConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return OutputConfig(
      features: yaml['features'] as String? ?? 'lib/features',
      jobs: yaml['jobs'] as String? ?? 'lib/core/jobs',
      executors: yaml['executors'] as String? ?? 'lib/core/executors',
    );
  }
}

/// Feature scaffold configuration
class FeatureConfig {
  final bool includeJob;
  final bool includeExecutor;
  final bool generateBarrel;

  const FeatureConfig({
    this.includeJob = true,
    this.includeExecutor = true,
    this.generateBarrel = true,
  });

  factory FeatureConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return FeatureConfig(
      includeJob: yaml['include_job'] as bool? ?? true,
      includeExecutor: yaml['include_executor'] as bool? ?? true,
      generateBarrel: yaml['generate_barrel'] as bool? ?? true,
    );
  }
}

/// Loads configuration from orchestrator.yaml
class ConfigLoader {
  /// Finds and loads the orchestrator.yaml config file
  /// Searches from the current directory up to the root
  static Future<OrchestratorConfig?> load() async {
    var dir = Directory.current;

    while (true) {
      final configFile = File(path.join(dir.path, 'orchestrator.yaml'));
      if (await configFile.exists()) {
        return await _loadFromFile(configFile);
      }

      final parent = dir.parent;
      if (parent.path == dir.path) {
        // Reached root, no config found
        return null;
      }
      dir = parent;
    }
  }

  /// Load config from a specific file
  static Future<OrchestratorConfig> _loadFromFile(File file) async {
    final content = await file.readAsString();
    final yaml = loadYaml(content) as Map<dynamic, dynamic>?;

    if (yaml == null) {
      return const OrchestratorConfig();
    }

    return OrchestratorConfig.fromYaml(yaml);
  }

  /// Get config or default if not found
  static Future<OrchestratorConfig> loadOrDefault() async {
    return await load() ?? const OrchestratorConfig();
  }
}
