import 'dart:io';

import 'package:mason/mason.dart';
import 'package:path/path.dart' as path;

/// Brick types supported by the CLI
enum BrickType {
  job,
  executor,
  state,
  cubit,
  notifier,
  riverpod,
}

/// Utility class to load bundled Mason bricks
class BrickLoader {
  /// Get the path to custom templates directory
  static String? getCustomTemplatesPath() {
    final customPath = path.join(Directory.current.path, '.orchestrator', 'templates');
    if (Directory(customPath).existsSync()) {
      return customPath;
    }
    return null;
  }

  /// Check if a custom template exists for the given type
  static bool hasCustomTemplate(BrickType type) {
    final customPath = getCustomTemplatesPath();
    if (customPath == null) return false;
    
    final templatePath = path.join(customPath, type.name);
    final brickYaml = File(path.join(templatePath, 'brick.yaml'));
    return brickYaml.existsSync();
  }

  /// Get the path to bundled bricks directory
  static String getBricksPath() {
    // Try to find the bricks directory relative to the script or package
    final scriptPath = Platform.script.toFilePath();
    
    // When running from source: bin/orchestrator.dart
    // Package root is parent of bin
    var packageRoot = path.dirname(path.dirname(scriptPath));
    var bricksPath = path.join(packageRoot, 'lib', 'src', 'bricks');
    
    if (Directory(bricksPath).existsSync()) {
      return bricksPath;
    }
    
    // When running from pub global activate or dart run
    // Look for bricks relative to current directory
    final currentDir = Directory.current.path;
    
    // Check if we're in the package directory
    bricksPath = path.join(currentDir, 'lib', 'src', 'bricks');
    if (Directory(bricksPath).existsSync()) {
      return bricksPath;
    }
    
    // Fallback: Look in packages/orchestrator_cli
    bricksPath = path.join(currentDir, 'packages', 'orchestrator_cli', 'lib', 'src', 'bricks');
    if (Directory(bricksPath).existsSync()) {
      return bricksPath;
    }
    
    throw StateError('Could not find bricks directory. '
        'Make sure you are running from the correct directory.');
  }

  /// Generate files from a brick (custom templates take priority)
  static Future<List<GeneratedFile>> generate({
    required BrickType type,
    required Map<String, dynamic> vars,
    required String outputDir,
    bool preferCustom = true,
  }) async {
    final brickName = type.name;
    String brickPath;

    // Check for custom template first
    if (preferCustom && hasCustomTemplate(type)) {
      final customPath = getCustomTemplatesPath()!;
      brickPath = path.join(customPath, brickName);
    } else {
      final bricksPath = getBricksPath();
      brickPath = path.join(bricksPath, brickName);
    }
    
    final brick = Brick.path(brickPath);
    final generator = await MasonGenerator.fromBrick(brick);
    
    final target = DirectoryGeneratorTarget(Directory(outputDir));
    
    return await generator.generate(
      target,
      vars: vars,
      fileConflictResolution: FileConflictResolution.skip,
    );
  }

  /// Get default output directory for a brick type
  static String getDefaultOutputDir(BrickType type) {
    switch (type) {
      case BrickType.job:
        return 'lib/jobs';
      case BrickType.executor:
        return 'lib/executors';
      case BrickType.state:
        return 'lib/states';
      case BrickType.cubit:
        return 'lib/cubits';
      case BrickType.notifier:
        return 'lib/notifiers';
      case BrickType.riverpod:
        return 'lib/notifiers';
    }
  }
}
