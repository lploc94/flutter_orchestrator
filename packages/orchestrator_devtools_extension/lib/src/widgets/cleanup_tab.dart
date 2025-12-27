import 'dart:convert';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

class CleanupTab extends StatefulWidget {
  const CleanupTab({super.key});

  @override
  State<CleanupTab> createState() => _CleanupTabState();
}

class _CleanupTabState extends State<CleanupTab> {
  bool _isLoading = false;
  bool _isAvailable = false;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _lastReport;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  Future<String?> _getIsolateId() async {
    final service = serviceManager.service;
    if (service == null) return null;
    final vm = await service.getVM();
    return vm.isolates?.firstOrNull?.id;
  }

  Future<void> _refreshStats() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final isolateId = await _getIsolateId();
      if (isolateId == null) {
        throw Exception('No isolate found');
      }

      final response = await serviceManager.service!.callServiceExtension(
        'ext.orchestrator.cleanup.getStats',
        isolateId: isolateId,
      );

      final json = response.json;
      if (json != null) {
        setState(() {
          _isAvailable = json['available'] == true;
          if (_isAvailable) {
            _stats = json;
          } else {
            _error = "Cleanup Service not configured in the app.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _runCleanup() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final isolateId = await _getIsolateId();
      if (isolateId == null) {
        throw Exception('No isolate found');
      }

      final response = await serviceManager.service!.callServiceExtension(
        'ext.orchestrator.cleanup.run',
        isolateId: isolateId,
      );

      final json = response.json;
      if (json != null) {
        setState(() {
          _lastReport = json;
        });
        // Auto refresh stats after cleanup
        if (mounted) {
          // Small delay to allow async operations to settle
          await Future.delayed(const Duration(milliseconds: 500));
          // We are already inside async function, but _refreshStats sets _isLoading=true
          // so we must ensure we reset it first, but logic below handles it.
          // Actually, better to call refresh separately.
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _refreshStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && !_isAvailable) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(_error!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshStats,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resource Cleanup',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshStats,
                    tooltip: 'Refresh Stats',
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _runCleanup,
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('Run Cleanup Now'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildStatsCards(context),
          if (_lastReport != null) ...[
            const SizedBox(height: 24),
            _buildLastReport(context),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCards(BuildContext context) {
    if (_stats == null) return const SizedBox();

    final cacheCount = _stats!['cacheEntryCount'] as int;
    final maxCache = _stats!['maxCacheEntries'] as int;
    final fileCount = _stats!['fileCount'] as int;
    final fileBytes = _stats!['fileSizeBytes'] as int;

    double cacheRatio = maxCache > 0 ? cacheCount / maxCache : 0.0;
    if (cacheRatio > 1.0) cacheRatio = 1.0;

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.memory, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Cache Memory',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$cacheCount / ${maxCache == 0 ? "Unlimited" : maxCache} entries',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: cacheRatio),
                  const SizedBox(height: 8),
                  Text(
                    '${(cacheRatio * 100).toStringAsFixed(1)}% Usage',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_open, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'File Storage',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$fileCount files',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    _formatBytes(fileBytes),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLastReport(BuildContext context) {
    final report = _lastReport!;
    return Card(
      color: Colors.green.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Last Cleanup Report',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('⏱️ Duration: ${report['durationMs']} ms'),
            Text('🗑️ Cache Removed: ${report['cacheEntriesRemoved']}'),
            Text('📂 Files Removed: ${report['filesRemoved']}'),
            Text('💾 Space Reclaimed: ${_formatBytes(report['bytesFreed'])}'),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
