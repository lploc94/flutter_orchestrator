import 'dart:async';
import 'package:flutter/material.dart';

class FilterBar extends StatefulWidget {
  final List<String> jobTypes;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onJobTypeChanged;
  final ValueChanged<bool> onErrorFilterChanged;
  final bool showErrorsOnly;

  const FilterBar({
    super.key,
    required this.jobTypes,
    required this.onSearchChanged,
    required this.onJobTypeChanged,
    required this.onErrorFilterChanged,
    required this.showErrorsOnly,
  });

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String? _selectedJobType;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.onSearchChanged(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search ID, Type...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 12,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Errors Only'),
                selected: widget.showErrorsOnly,
                onSelected: widget.onErrorFilterChanged,
                avatar: widget.showErrorsOnly
                    ? const Icon(Icons.check, size: 16)
                    : null,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Filter Job:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: DropdownButtonFormField<String>(
                    value: _selectedJobType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      isDense: true,
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 12),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Jobs'),
                      ),
                      ...widget.jobTypes.map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedJobType = value);
                      widget.onJobTypeChanged(value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
