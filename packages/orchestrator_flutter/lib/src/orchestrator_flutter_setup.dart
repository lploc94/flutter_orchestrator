import 'package:orchestrator_core/orchestrator_core.dart';
import 'file_offline_storage.dart';
import 'flutter_cleanup_service.dart';
import 'flutter_connectivity_provider.dart';
import 'flutter_file_safety.dart';

/// Entry point for setting up Orchestrator with Flutter integration.
class OrchestratorFlutter {
  /// Initialize all Flutter-specific integrations with default settings.
  ///
  /// This configures:
  /// 1. [ConnectivityProvider] using `connectivity_plus`.
  /// 2. [CleanupService] for automatic resource optimization (optional).
  /// 3. [NetworkQueueManager] with file-based storage.
  ///
  /// Parameters:
  /// - [enableAutoCleanup]: Set to `false` to disable automatic cleanup entirely.
  /// - [cleanupPolicy]: Custom cleanup configuration (advanced).
  /// - [enableDevTools]: Reserved for future DevTools integration.
  ///
  /// Usage:
  /// ```dart
  /// void main() {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   OrchestratorFlutter.initialize(); // Default: auto cleanup ON
  ///   runApp(MyApp());
  /// }
  ///
  /// // Or disable auto cleanup:
  /// OrchestratorFlutter.initialize(enableAutoCleanup: false);
  /// ```
  static void initialize({
    bool enableAutoCleanup = true,
    CleanupPolicy? cleanupPolicy,
    bool enableDevTools = true,
    // Optional overrides
    OrchestratorLogger? logger,
    CacheProvider? cacheProvider,
    int? maxEventsPerSecond,
  }) {
    // 0. Base Config
    if (logger != null) {
      OrchestratorConfig.setLogger(logger);
    }
    if (maxEventsPerSecond != null) {
      OrchestratorConfig.maxEventsPerSecond = maxEventsPerSecond;
    }
    if (cacheProvider != null) {
      OrchestratorConfig.setCacheProvider(cacheProvider);
    }

    // 1. Connectivity
    // Only set if it's currently the default (AlwaysOnlineProvider) to avoid overwriting user config
    if (OrchestratorConfig.connectivityProvider is AlwaysOnlineProvider) {
      OrchestratorConfig.setConnectivityProvider(FlutterConnectivityProvider());
    }

    // 2. File Safety & Storage (Needed for Queue & Cleanup)
    final fileSafety = FlutterFileSafety();
    final storage = FileNetworkQueueStorage();

    // 3. Network Queue Manager
    // Only set if not already configured
    if (OrchestratorConfig.networkQueueManager == null) {
      final queueManager = NetworkQueueManager(
        storage: storage,
        fileDelegate: fileSafety,
      );
      OrchestratorConfig.setNetworkQueueManager(queueManager);
    }

    // Capture the (possibly updated) queue manager for cleanup service
    final activeQueueManager = OrchestratorConfig.networkQueueManager;

    // 4. Cleanup Service (only if enabled)
    if (enableAutoCleanup) {
      final effectivePolicy = cleanupPolicy ?? CleanupPolicy.defaultPolicy;
      final activeCacheProvider = OrchestratorConfig.cacheProvider;

      // Sync maxCacheEntries from Policy to CacheProvider if possible
      if (activeCacheProvider is InMemoryCacheProvider) {
        // Ensure the cache provider respects the policy's limit
        // This keeps manual and auto config in sync
        if (effectivePolicy.maxCacheEntries > 0) {
          activeCacheProvider.maxEntries = effectivePolicy.maxCacheEntries;
        }
      }

      // Create service if not exists or force update?
      // For now, we set it if user requested enableAutoCleanup
      final cleanupService = FlutterCleanupService(
        policy: effectivePolicy,
        cacheProvider: activeCacheProvider,
        fileSafety: fileSafety,
        networkQueueManager: activeQueueManager,
      );
      OrchestratorConfig.setCleanupService(cleanupService);
    }

    // 5. DevTools & Logging
    if (enableDevTools) {
      // Future: Setup DevTools extension communication if needed
    }
  }
}
