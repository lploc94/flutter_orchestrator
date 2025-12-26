import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../utils/logger.dart';

/// Template command group - manages custom templates
class TemplateCommand extends Command<int> {
  TemplateCommand() {
    addSubcommand(TemplateInitCommand());
    addSubcommand(TemplateListCommand());
  }

  @override
  String get name => 'template';

  @override
  String get description => 'Manage custom templates';
}

/// Initialize custom templates by copying bundled bricks
class TemplateInitCommand extends Command<int> {
  TemplateInitCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Overwrite existing custom templates',
      negatable: false,
    );
    argParser.addOption(
      'template',
      abbr: 't',
      help: 'Specific template to initialize (job, executor, state, cubit, notifier, riverpod)',
      allowed: ['job', 'executor', 'state', 'cubit', 'notifier', 'riverpod', 'all'],
      defaultsTo: 'all',
    );
  }

  @override
  String get name => 'init';

  @override
  String get description => 'Initialize custom templates for customization';

  @override
  Future<int> run() async {
    final logger = CliLogger();
    final force = argResults?['force'] as bool? ?? false;
    final templateArg = argResults?['template'] as String? ?? 'all';

    logger.info('🎨 Initializing custom templates...\n');

    final customDir = Directory('.orchestrator/templates');
    
    // Check if custom templates already exist
    if (customDir.existsSync() && !force) {
      final existing = customDir.listSync().whereType<Directory>().toList();
      if (existing.isNotEmpty) {
        logger.warn('Custom templates already exist:');
        for (final dir in existing) {
          logger.detail('  • ${path.basename(dir.path)}');
        }
        logger.info('');
        logger.info('Use --force to overwrite existing templates.');
        return 1;
      }
    }

    // Create custom templates directory
    await customDir.create(recursive: true);

    // Get the path to bundled bricks
    final packageUri = await _getPackagePath();
    if (packageUri == null) {
      logger.error('Could not locate orchestrator_cli package');
      return 1;
    }

    final bricksDir = Directory(path.join(packageUri, 'lib', 'src', 'bricks'));
    if (!bricksDir.existsSync()) {
      logger.error('Bundled bricks not found at ${bricksDir.path}');
      return 1;
    }

    final templates = templateArg == 'all'
        ? ['job', 'executor', 'state', 'cubit', 'notifier', 'riverpod']
        : [templateArg];

    int copied = 0;
    for (final template in templates) {
      final sourceDir = Directory(path.join(bricksDir.path, template));
      final targetDir = Directory(path.join(customDir.path, template));

      if (!sourceDir.existsSync()) {
        logger.warn('Template "$template" not found, skipping');
        continue;
      }

      if (targetDir.existsSync() && !force) {
        logger.detail('  Skipping $template (already exists)');
        continue;
      }

      // Copy the template
      await _copyDirectory(sourceDir, targetDir);
      logger.success('  ✓ Copied $template template');
      copied++;
    }

    if (copied > 0) {
      logger.info('');
      logger.success('✨ Custom templates initialized!');
      logger.info('');
      logger.info('📁 Location: .orchestrator/templates/');
      logger.info('');
      logger.info('💡 Next steps:');
      logger.detail('  1. Edit templates in .orchestrator/templates/<name>/__brick__/');
      logger.detail('  2. Templates use Mustache syntax ({{name.pascalCase()}})');
      logger.detail('  3. Run `orchestrator create <type> <name>` to use your custom templates');
      logger.info('');
      logger.info('📚 Template variables available:');
      logger.detail('  • {{name}} - Raw name as provided');
      logger.detail('  • {{name.pascalCase()}} - PascalCase (e.g., FetchUser)');
      logger.detail('  • {{name.camelCase()}} - camelCase (e.g., fetchUser)');
      logger.detail('  • {{name.snakeCase()}} - snake_case (e.g., fetch_user)');
      logger.detail('  • {{name.constantCase()}} - CONSTANT_CASE (e.g., FETCH_USER)');
    } else {
      logger.info('No templates were copied.');
    }

    return 0;
  }

  /// Get the path to the orchestrator_cli package
  Future<String?> _getPackagePath() async {
    // Try to find the package in common locations
    final possiblePaths = [
      // Development: running from source
      Directory.current.path,
      // Check parent directories (monorepo structure)
      path.dirname(Directory.current.path),
      path.join(path.dirname(Directory.current.path), 'packages', 'orchestrator_cli'),
    ];

    for (final p in possiblePaths) {
      final pubspecFile = File(path.join(p, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        final content = await pubspecFile.readAsString();
        if (content.contains('name: orchestrator_cli')) {
          return p;
        }
      }
    }

    // Try to resolve from package config
    final packageConfig = File('.dart_tool/package_config.json');
    if (packageConfig.existsSync()) {
      final content = await packageConfig.readAsString();
      final match = RegExp(r'"rootUri":\s*"file://([^"]+orchestrator_cli[^"]*)"')
          .firstMatch(content);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Copy a directory recursively
  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);

    await for (final entity in source.list(recursive: false)) {
      final targetPath = path.join(target.path, path.basename(entity.path));

      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      }
    }
  }
}

/// List custom templates
class TemplateListCommand extends Command<int> {
  @override
  String get name => 'list';

  @override
  String get description => 'List custom templates';

  @override
  Future<int> run() async {
    final logger = CliLogger();
    final customDir = Directory('.orchestrator/templates');

    if (!customDir.existsSync()) {
      logger.info('No custom templates found.');
      logger.detail('Run `orchestrator template init` to create custom templates.');
      return 0;
    }

    logger.info('🎨 Custom Templates\n');

    final templates = customDir.listSync().whereType<Directory>().toList();
    if (templates.isEmpty) {
      logger.info('No custom templates found.');
      return 0;
    }

    for (final template in templates) {
      final templateName = path.basename(template.path);
      final brickYaml = File(path.join(template.path, 'brick.yaml'));
      
      if (brickYaml.existsSync()) {
        logger.success('  $templateName');
        logger.detail('    Path: ${template.path}');
        
        // List files in __brick__
        final brickDir = Directory(path.join(template.path, '__brick__'));
        if (brickDir.existsSync()) {
          final files = brickDir.listSync(recursive: true).whereType<File>();
          for (final file in files) {
            final relativePath = path.relative(file.path, from: brickDir.path);
            logger.detail('    • $relativePath');
          }
        }
      }
    }

    return 0;
  }
}
