import 'dart:async';
// import 'dart:convert'; // removed

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import 'models/event_entry.dart';
import 'widgets/event_timeline_tab.dart';
import 'widgets/executor_registry_tab.dart';
import 'widgets/job_inspector_tab.dart';
import 'widgets/network_queue_tab.dart';
import 'widgets/filter_bar.dart';
import 'widgets/metrics_tab.dart';

/// Main inspector widget with 4 tabs: Events, Jobs, Executors, Network Queue.
class OrchestratorInspector extends StatefulWidget {
  const OrchestratorInspector({super.key});

  @override
  State<OrchestratorInspector> createState() => _OrchestratorInspectorState();
}

class _OrchestratorInspectorState extends State<OrchestratorInspector> {
  final List<EventEntry> _events = [];
  final Map<String, String> _executorRegistry = {}; // Registry state
  List<Map<String, dynamic>> _networkQueue = []; // Offline Queue
  String _connectionStatus = 'Disconnected';
  StreamSubscription? _sub;

  // Filter State
  final TextEditingController _searchController = TextEditingController();
  bool _showErrorsOnly = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _setupEventListener();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      setState(() {
        // Trigger rebuild to filter events
      });
    });
  }

  // _submitSearch removed because it was unused

  void _setupEventListener() async {
    // Prevent multiple concurrent connection attempts
    if (_connectionStatus.startsWith('Connecting') ||
        _connectionStatus.startsWith('Service connected')) {
      return;
    }

    setState(() => _connectionStatus = 'Connecting...');
    debugPrint(
      '[OrchestratorInspector] 🔄 Initializing connection to VM Service...',
    );

    try {
      // unused import removed

      // 1. Check if already connected
      VmService? service;
      if (serviceManager.connectedState.value.connected) {
        service = serviceManager.service;
        debugPrint('[OrchestratorInspector] ✅ Service already connected.');
      } else {
        debugPrint(
          '[OrchestratorInspector] ⏳ Waiting for VM Service to become available...',
        );
        // Wait for service to be available
        service = await serviceManager.onServiceAvailable;
      }

      if (service == null) {
        throw Exception('Service is null after onServiceAvailable');
      }

      setState(() => _connectionStatus = 'Service connected, subscribing...');
      debugPrint(
        '[OrchestratorInspector] ✅ VM Service available, subscribing...',
      );

      // 2. Subscribe to the 'Extension' stream
      try {
        await service.streamListen('Extension');
        setState(() => _connectionStatus = 'Connected (Subscribed)');
        debugPrint(
          '[OrchestratorInspector] ✅ Successfully subscribed to Extension stream',
        );
      } catch (e) {
        // It might be already subscribed, which is fine
        // check if error contains "Stream already subscribed" to be sure
        final errorStr = e.toString();
        if (errorStr.contains('103') ||
            errorStr.contains('Stream already subscribed')) {
          setState(() => _connectionStatus = 'Connected (Resumed)');
          debugPrint(
            '[OrchestratorInspector] ℹ️ Stream already subscribed, resuming.',
          );
        } else {
          rethrow; // Re-throw other errors
        }
      }

      // 3. Cancel previous subscription if any
      await _sub?.cancel();

      // 4. Listen to ALL events on the Extension stream
      _sub = service
          .onEvent('Extension')
          .listen(
            (event) {
              // Filter for orchestrator events
              if (event.extensionKind == 'ext.orchestrator.event') {
                _handleExtensionEvent(event);
              }
            },
            onError: (error) {
              debugPrint('[OrchestratorInspector] ❌ Stream error: $error');
              setState(
                () => _connectionStatus = 'Stream Error (Auto-reconnecting)',
              );
              // Auto-reconnect on error
              Future.delayed(const Duration(seconds: 2), _setupEventListener);
            },
            onDone: () {
              debugPrint('[OrchestratorInspector] ⚠️ Stream done/closed');
              setState(
                () => _connectionStatus = 'Disconnected (Stream Closed)',
              );
            },
          );

      // 5. Fetch Initial Data
      _fetchInitialData(service);
    } catch (e) {
      setState(() => _connectionStatus = 'Failed to connect');
      debugPrint(
        '[OrchestratorInspector] ❌ Error connecting to VM Service: $e',
      );

      // 5. Auto-retry logic
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          debugPrint('[OrchestratorInspector] 🔄 Auto-retrying connection...');
          _setupEventListener();
        }
      });
    }
  }

  Future<void> _fetchInitialData(VmService service) async {
    await _fetchRegistry(service);
    await _fetchNetworkQueue(service);
  }

  Future<void> _fetchRegistry(VmService service) async {
    try {
      debugPrint('[OrchestratorInspector] 📥 requesting registry...');

      // Get the main isolate ID first
      final vm = await service.getVM();
      final isolateId = vm.isolates?.firstOrNull?.id;
      if (isolateId == null) {
        debugPrint('[OrchestratorInspector] ⚠️ No isolate found');
        return;
      }

      final response = await service.callServiceExtension(
        'ext.orchestrator.getRegistry',
        isolateId: isolateId,
      );

      final json = response.json;
      debugPrint('[OrchestratorInspector] 📥 Response JSON: $json');

      if (json != null && json['registry'] != null) {
        final newData = Map<String, String>.from(json['registry']);
        setState(() {
          _executorRegistry.clear();
          _executorRegistry.addAll(newData);
        });
        debugPrint(
          '[OrchestratorInspector] ✅ Registry fetched via Service Extension: $_executorRegistry',
        );
      } else {
        debugPrint('[OrchestratorInspector] ⚠️ Response has no registry key');
      }
    } catch (e, stack) {
      debugPrint('[OrchestratorInspector] ⚠️ Failed to fetch registry: $e');
      debugPrint('[OrchestratorInspector] Stack: $stack');
    }
  }

  Future<void> _fetchNetworkQueue(VmService service) async {
    try {
      debugPrint('[OrchestratorInspector] 📥 requesting network queue...');
      final vm = await service.getVM();
      final isolateId = vm.isolates?.firstOrNull?.id;
      if (isolateId == null) return;

      final response = await service.callServiceExtension(
        'ext.orchestrator.getNetworkQueue',
        isolateId: isolateId,
      );

      final json = response.json;
      debugPrint('[OrchestratorInspector] 📥 Queue JSON: $json');

      if (json != null && json['queue'] != null) {
        final newQueue = List<Map<String, dynamic>>.from(json['queue']);
        setState(() {
          _networkQueue = newQueue;
        });
        debugPrint(
          '[OrchestratorInspector] ✅ Network Queue fetched: ${_networkQueue.length} items',
        );
      }
    } catch (e) {
      debugPrint('[OrchestratorInspector] ⚠️ Failed to fetch queue: $e');
    }
  }

  /// Separate logic for handling the event data
  void _handleExtensionEvent(Event event) {
    debugPrint('[OrchestratorInspector] 📥 RX Event: ${event.extensionKind}');

    // Try to get data from several possible locations
    Map<String, dynamic>? data;

    if (event.extensionData?.data != null) {
      data = Map<String, dynamic>.from(event.extensionData!.data);
    } else if (event.json != null) {
      // Fallback: try to access from json directly
      final extData = event.json!['extensionData'];
      if (extData is Map && extData['data'] is Map) {
        data = Map<String, dynamic>.from(extData['data'] as Map);
      }
    }

    if (data != null) {
      // Check for Registry Event
      if (data['type'] == 'ExecutorRegistryEvent' && data['registry'] != null) {
        final newData = Map<String, String>.from(data['registry']);
        setState(() {
          _executorRegistry.clear();
          _executorRegistry.addAll(newData);
        });
        return; // Don't add to event log
      }

      // Normal Event
      var entry = EventEntry.fromJson(data);

      // Enrich with JobType
      if (entry.jobType != null) {
        _correlationToJobType[entry.correlationId] = entry.jobType!;
        _knownJobTypes.add(entry.jobType!);
      } else if (_correlationToJobType.containsKey(entry.correlationId)) {
        // Hydrate from history
        final type = _correlationToJobType[entry.correlationId];
        // Create new entry with jobType (since EventEntry is immutable-ish)
        entry = EventEntry(
          type: entry.type,
          correlationId: entry.correlationId,
          timestamp: entry.timestamp,
          rawData: entry.rawData,
          jobType: type,
        );
      }

      setState(() {
        _events.insert(0, entry);
        if (_events.length > 500) _events.removeLast();
      });
    }
  }

  // Job Type state
  final Set<String> _knownJobTypes = {};
  String? _selectedJobType;
  final Map<String, String> _correlationToJobType = {};

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _getFilteredEvents();

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Orchestrator Inspector'),
              Text(
                'Status: $_connectionStatus',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reconnect / Refresh',
              onPressed: _setupEventListener,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear events',
              onPressed: _clearEvents,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Events', icon: Icon(Icons.timeline)),
              Tab(text: 'Jobs', icon: Icon(Icons.work_outline)),
              Tab(text: 'Executors', icon: Icon(Icons.hub)),
              Tab(text: 'Network Queue', icon: Icon(Icons.cloud_queue)),
              Tab(text: 'Metrics', icon: Icon(Icons.analytics)),
            ],
          ),
        ),
        body: Column(
          children: [
            FilterBar(
              jobTypes: _knownJobTypes.toList()..sort(),
              showErrorsOnly: _showErrorsOnly,
              onSearchChanged: (val) {
                _searchController.text = val;
                setState(() {});
              },
              onJobTypeChanged: (val) {
                setState(() => _selectedJobType = val);
              },
              onErrorFilterChanged: (val) {
                setState(() => _showErrorsOnly = val);
              },
            ),
            Expanded(
              child: TabBarView(
                children: [
                  EventTimelineTab(events: filteredEvents),
                  JobInspectorTab(events: filteredEvents),
                  ExecutorRegistryTab(registry: _executorRegistry),
                  NetworkQueueTab(queue: _networkQueue),
                  MetricsTab(
                    events: _events,
                    executorCount: _executorRegistry.length,
                    networkQueueSize: _networkQueue.length,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearEvents() {
    setState(() {
      _events.clear();
      _knownJobTypes.clear();
      _correlationToJobType.clear();
    });
  }

  List<EventEntry> _getFilteredEvents() {
    return _events.where((event) {
      // 1. Search Query
      final query = _searchController.text.toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          event.type.toLowerCase().contains(query) ||
          event.correlationId.toLowerCase().contains(query) ||
          (event.jobType?.toLowerCase().contains(query) ?? false);

      // 2. Error Filter
      final matchesError =
          !_showErrorsOnly ||
          event.type == 'JobFailureEvent' ||
          event.type == 'NetworkSyncFailureEvent';

      // 3. Job Type Filter
      final matchesJobType =
          _selectedJobType == null || event.jobType == _selectedJobType;

      return matchesQuery && matchesError && matchesJobType;
    }).toList();
  }
}
