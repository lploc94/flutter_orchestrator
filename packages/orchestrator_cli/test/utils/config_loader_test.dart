import 'package:orchestrator_cli/src/utils/config_loader.dart';
import 'package:test/test.dart';

void main() {
  group('OrchestratorConfig', () {
    test('should have default values', () {
      const config = OrchestratorConfig();
      
      expect(config.stateManagement, equals('cubit'));
      expect(config.output.features, equals('lib/features'));
      expect(config.output.jobs, equals('lib/core/jobs'));
      expect(config.output.executors, equals('lib/core/executors'));
      expect(config.feature.includeJob, isTrue);
      expect(config.feature.includeExecutor, isTrue);
      expect(config.feature.generateBarrel, isTrue);
    });

    test('should parse from yaml map', () {
      final yaml = {
        'state_management': 'riverpod',
        'output': {
          'features': 'lib/modules',
          'jobs': 'lib/jobs',
          'executors': 'lib/executors',
        },
        'feature': {
          'include_job': false,
          'include_executor': true,
          'generate_barrel': false,
        },
      };

      final config = OrchestratorConfig.fromYaml(yaml);

      expect(config.stateManagement, equals('riverpod'));
      expect(config.output.features, equals('lib/modules'));
      expect(config.output.jobs, equals('lib/jobs'));
      expect(config.output.executors, equals('lib/executors'));
      expect(config.feature.includeJob, isFalse);
      expect(config.feature.includeExecutor, isTrue);
      expect(config.feature.generateBarrel, isFalse);
    });

    test('should handle partial yaml map', () {
      final yaml = {
        'state_management': 'provider',
      };

      final config = OrchestratorConfig.fromYaml(yaml);

      expect(config.stateManagement, equals('provider'));
      // Should use defaults for missing values
      expect(config.output.features, equals('lib/features'));
      expect(config.feature.includeJob, isTrue);
    });

    test('should handle empty yaml map', () {
      final yaml = <String, dynamic>{};

      final config = OrchestratorConfig.fromYaml(yaml);

      expect(config.stateManagement, equals('cubit'));
    });
  });

  group('OutputConfig', () {
    test('should have default values', () {
      const output = OutputConfig();

      expect(output.features, equals('lib/features'));
      expect(output.jobs, equals('lib/core/jobs'));
      expect(output.executors, equals('lib/core/executors'));
    });

    test('should parse from yaml map', () {
      final yaml = {
        'features': 'src/features',
        'jobs': 'src/jobs',
        'executors': 'src/executors',
      };

      final output = OutputConfig.fromYaml(yaml);

      expect(output.features, equals('src/features'));
      expect(output.jobs, equals('src/jobs'));
      expect(output.executors, equals('src/executors'));
    });
  });

  group('FeatureConfig', () {
    test('should have default values', () {
      const feature = FeatureConfig();

      expect(feature.includeJob, isTrue);
      expect(feature.includeExecutor, isTrue);
      expect(feature.generateBarrel, isTrue);
    });

    test('should parse from yaml map', () {
      final yaml = {
        'include_job': false,
        'include_executor': false,
        'generate_barrel': true,
      };

      final feature = FeatureConfig.fromYaml(yaml);

      expect(feature.includeJob, isFalse);
      expect(feature.includeExecutor, isFalse);
      expect(feature.generateBarrel, isTrue);
    });
  });

  group('ConfigLoader', () {
    test('loadOrDefault should return config', () async {
      final config = await ConfigLoader.loadOrDefault();
      expect(config, isA<OrchestratorConfig>());
    });
  });
}
