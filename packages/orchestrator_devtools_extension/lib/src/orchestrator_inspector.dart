import 'dart:async';
import 'dart:convert';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import 'models/event_entry.dart';
import 'widgets/event_timeline_tab.dart';
import 'widgets/executor_registry_tab.dart';
import 'widgets/job_inspector_tab.dart';
import 'widgets/network_queue_tab.dart';

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

  void _submitSearch() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() {});
  }

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
      // 1. Check if already connected
      VmService? service;
      if (serviceManager.hasConnection) {
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
      setState(() {
        _events.insert(0, EventEntry.fromJson(data!));
        if (_events.length > 500) _events.removeLast();
      });
    }
  }

  void _clearEvents() {
    setState(() {
      _events.clear();
    });
  }

  List<EventEntry> _getFilteredEvents() {
    if (_searchController.text.isEmpty && !_showErrorsOnly) {
      return _events;
    }

    final query = _searchController.text.toLowerCase();
    return _events.where((event) {
      final matchesQuery =
          query.isEmpty ||
          event.type.toLowerCase().contains(query) ||
          event.correlationId.toLowerCase().contains(query);

      final matchesFilter =
          !_showErrorsOnly ||
          event.type == 'JobFailureEvent' ||
          event.type == 'NetworkSyncFailureEvent';

      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _getFilteredEvents();

    return DefaultTabController(
      length: 4,
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
            ],
          ),
        ),
        body: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: TabBarView(
                children: [
                  EventTimelineTab(events: filteredEvents),
                  JobInspectorTab(events: filteredEvents),
                  ExecutorRegistryTab(registry: _executorRegistry),
                  NetworkQueueTab(queue: _networkQueue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search (Debounced 1.5s)...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.keyboard_return, size: 16),
                    onPressed: _submitSearch,
                    tooltip: 'Search Immediately',
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
                onSubmitted: (_) => _submitSearch(),
                textInputAction: TextInputAction.search,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Errors Only'),
            selected: _showErrorsOnly,
            onSelected: (value) => setState(() => _showErrorsOnly = value),
            avatar: _showErrorsOnly ? const Icon(Icons.check, size: 16) : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
