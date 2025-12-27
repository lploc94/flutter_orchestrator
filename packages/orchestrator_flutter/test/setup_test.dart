import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrator_flutter/orchestrator_flutter.dart';
import 'package:orchestrator_core/orchestrator_core.dart';
// Note: OrchestratorFlutter.initialize needs flutter binding

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Reset config before each test
  setUp(() {
    OrchestratorConfig.setCacheProvider(InMemoryCacheProvider());
    OrchestratorConfig.setCleanupService(FlutterCleanupService(
      cacheProvider: InMemoryCacheProvider(),
    )); // Dummy
    // Reset logger
    OrchestratorConfig.setLogger(NoOpLogger());
  });

  test('initialize setup default components', () {
    OrchestratorFlutter.initialize(enableAutoCleanup: false);

    expect(OrchestratorConfig.connectivityProvider,
        isA<FlutterConnectivityProvider>());
    expect(OrchestratorConfig.networkQueueManager, isNotNull);
  });

  test('initialize auto-syncs maxEntries to CacheProvider', () {
    // 1. Set explicit policy
    OrchestratorFlutter.initialize(
      enableAutoCleanup: true,
      cleanupPolicy: CleanupPolicy(maxCacheEntries: 5555),
    );

    // 2. Verify CleanupService is set
    expect(OrchestratorConfig.cleanupService, isNotNull);
    final service = OrchestratorConfig.cleanupService;
    expect(service!.policy.maxCacheEntries, 5555);

    // 3. Verify Auto-Sync to InMemoryCacheProvider
    final cache = OrchestratorConfig.cacheProvider as InMemoryCacheProvider;
    expect(cache.maxEntries, 5555,
        reason: "Cache maxEntries should be synced from Policy");
  });

  test('initialize respects manual config', () {
    // Manually set a logger
    final myLogger = NoOpLogger();
    OrchestratorConfig.setLogger(myLogger);

    // Initialize
    OrchestratorFlutter.initialize();

    // Should still be myLogger (unless we passed an override)
    expect(OrchestratorConfig.logger, equals(myLogger));
  });
}
