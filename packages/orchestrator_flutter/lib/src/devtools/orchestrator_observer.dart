import 'dart:async';
import 'dart:convert';

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// Observer that sends Orchestrator events to DevTools Inspector.
///
/// Automatically initialized in debug/profile mode when importing
/// `orchestrator_flutter`. No manual initialization required.
///
/// Events are sent via `dart:developer.postEvent()` with the extension
/// kind `ext.orchestrator.event`.
class OrchestratorObserver {
  static final OrchestratorObserver _instance = OrchestratorObserver._();

  /// Get the singleton instance.
  static OrchestratorObserver get instance => _instance;

  StreamSubscription<BaseEvent>? _subscription;
  bool _isListening = false;

  OrchestratorObserver._() {
    // Automatically activate in debug/profile mode
    if (kDebugMode || kProfileMode) {
      debugPrint(
          '[OrchestratorObserver] Initializing in ${kDebugMode ? "debug" : "profile"} mode');
      _startListening();
    }
  }

  void _startListening() {
    if (_isListening) return;
    _isListening = true;
    debugPrint('[OrchestratorObserver] Started listening to SignalBus');
    _subscription = SignalBus.instance.stream.listen(_onEvent);

    // Register Service Extension for DevTools to request Registry
    developer.registerExtension(
      'ext.orchestrator.getRegistry',
      (method, parameters) async {
        try {
          final registry = Dispatcher().registeredExecutors;
          // Return as JSON service response
          return developer.ServiceExtensionResponse.result(
            jsonEncode({'registry': registry}),
          );
        } catch (e) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.extensionError,
            'Failed to get registry: $e',
          );
        }
      },
    );

    // Register Service Extension for DevTools to request Network Queue
    developer.registerExtension(
      'ext.orchestrator.getNetworkQueue',
      (method, parameters) async {
        try {
          final manager = OrchestratorConfig.networkQueueManager;
          if (manager == null) {
            return developer.ServiceExtensionResponse.result(
              jsonEncode({'queue': []}),
            );
          }
          final jobs = await manager.getAllJobs();
          // jobs is List<Map<String, dynamic>> which is JSON encodable
          return developer.ServiceExtensionResponse.result(
            jsonEncode({'queue': jobs}),
          );
        } catch (e) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.extensionError,
            'Failed to get network queue: $e',
          );
        }
      },
    );

    // Register Service Extension for Cleanup Stats
    developer.registerExtension(
      'ext.orchestrator.cleanup.getStats',
      (method, parameters) async {
        try {
          final service = OrchestratorConfig.cleanupService;
          if (service == null) {
            return developer.ServiceExtensionResponse.result(
              jsonEncode({'available': false}),
            );
          }
          final stats = await service.getStats();
          return developer.ServiceExtensionResponse.result(
            jsonEncode({
              'available': true,
              'cacheEntryCount': stats.cacheEntryCount,
              'maxCacheEntries': stats.cacheMaxEntries,
              'fileCount': stats.fileCount,
              'fileSizeBytes': stats.fileSizeBytes,
            }),
          );
        } catch (e) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.extensionError,
            'Failed to get cleanup stats: $e',
          );
        }
      },
    );

    // Register Service Extension for Force Cleanup
    developer.registerExtension(
      'ext.orchestrator.cleanup.run',
      (method, parameters) async {
        try {
          final service = OrchestratorConfig.cleanupService;
          if (service == null) {
            return developer.ServiceExtensionResponse.result(
              jsonEncode(
                  {'success': false, 'error': 'No CleanupService configured'}),
            );
          }
          final report = await service.runCleanup();
          return developer.ServiceExtensionResponse.result(
            jsonEncode({
              'success': true,
              'cacheEntriesRemoved': report.cacheEntriesRemoved,
              'filesRemoved': report.filesRemoved,
              'bytesFreed': report.bytesFreed,
              'durationMs': report.duration.inMilliseconds,
            }),
          );
        } catch (e) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.extensionError,
            'Failed to run cleanup: $e',
          );
        }
      },
    );

    // Also send once at startup just in case
    _sendRegistryEvent();
  }

  void _sendRegistryEvent() {
    try {
      final registry = Dispatcher().registeredExecutors;
      final event = ExecutorRegistryEvent(registry);
      _onEvent(event);
    } catch (e) {
      debugPrint('[OrchestratorObserver] Failed to send registry event: $e');
    }
  }

  void _onEvent(BaseEvent event) {
    debugPrint('[OrchestratorObserver] Received event: ${event.runtimeType}');
    developer.postEvent('ext.orchestrator.event', _eventToJson(event));
  }

  /// Convert event to JSON for DevTools.
  Map<String, dynamic> _eventToJson(BaseEvent event) {
    final json = <String, dynamic>{
      'type': event.runtimeType.toString(),
      'correlationId': event.correlationId,
      'timestamp': event.timestamp.toIso8601String(),
    };

    // Add event-specific fields
    if (event is JobStartedEvent) {
      json['jobType'] = event.jobType;
    } else if (event is JobSuccessEvent) {
      json['data'] = _sanitizeData(event.data);
      json['isOptimistic'] = event.isOptimistic;
    } else if (event is JobFailureEvent) {
      json['error'] = _sanitizeData(event.error);
      json['wasRetried'] = event.wasRetried;
    } else if (event is JobCancelledEvent) {
      json['reason'] = event.reason;
    } else if (event is JobTimeoutEvent) {
      json['timeout'] = event.timeout.inMilliseconds;
    } else if (event is JobProgressEvent) {
      json['progress'] = event.progress;
      json['message'] = event.message;
      json['currentStep'] = event.currentStep;
      json['totalSteps'] = event.totalSteps;
    } else if (event is JobRetryingEvent) {
      json['attempt'] = event.attempt;
      json['maxRetries'] = event.maxRetries;
      json['lastError'] = event.lastError.toString();
      json['delayBeforeRetry'] = event.delayBeforeRetry.inMilliseconds;
    } else if (event is NetworkSyncFailureEvent) {
      json['error'] = event.error.toString();
      json['retryCount'] = event.retryCount;
      json['isPoisoned'] = event.isPoisoned;
    } else if (event is JobCacheHitEvent) {
      json['data'] = _sanitizeData(event.data);
    } else if (event is JobPlaceholderEvent) {
      json['data'] = _sanitizeData(event.data);
    } else if (event is ExecutorRegistryEvent) {
      json['registry'] = event.registry;
    }

    return json;
  }

  /// Recursively sanitizes data for JSON transmission.
  ///
  /// Tries to convert objects to JSON-encodable format:
  /// - Primitives: returned as-is
  /// - DateTime: .toIso8601String()
  /// - List/Map: recursive sanitization
  /// - Objects with .toJson(): called via dynamic invocation
  /// - Fallback: .toString()
  dynamic _sanitizeData(dynamic data) {
    if (data == null) return null;
    if (data is String || data is num || data is bool) return data;
    if (data is DateTime) return data.toIso8601String();

    if (data is List) {
      return data.map(_sanitizeData).toList();
    }

    if (data is Map) {
      return data
          .map((key, value) => MapEntry(key.toString(), _sanitizeData(value)));
    }

    try {
      // Try calling toJson() dynamically
      // ignore: avoid_dynamic_calls
      return (data as dynamic).toJson();
    } catch (_) {
      // Fallback
      return data.toString();
    }
  }

  /// Dispose the observer (for testing).
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
  }
}

/// Initialize the DevTools Observer for Orchestrator events.
///
/// Call this in your `main()` function to enable event monitoring in DevTools:
/// ```dart
/// void main() {
///   initDevToolsObserver();
///   runApp(MyApp());
/// }
/// ```
///
/// Only works in debug/profile mode. No-op in release mode.
void initDevToolsObserver() {
  // Just accessing the instance triggers initialization in constructor
  OrchestratorObserver.instance;
}
