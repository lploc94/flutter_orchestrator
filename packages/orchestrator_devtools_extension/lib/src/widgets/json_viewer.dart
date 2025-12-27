import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

/// A interactive JSON tree viewer for inspecting data
class JsonViewer extends StatelessWidget {
  final dynamic data;
  final double fontSize;

  const JsonViewer({super.key, required this.data, this.fontSize = 13.0});

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Text(
        'null',
        style: TextStyle(color: Colors.grey, fontSize: fontSize),
      );
    }

    // Root level handling to avoid extra padding for top level if it's not a container
    return _buildNode(data);
  }

  Widget _buildNode(dynamic node) {
    if (node == null) {
      return Text(
        'null',
        style: TextStyle(color: Colors.grey, fontSize: fontSize),
      );
    }
    if (node is String) {
      return SelectableText(
        '"$node"',
        style: TextStyle(color: Colors.green, fontSize: fontSize),
      );
    }
    if (node is num) {
      return SelectableText(
        node.toString(),
        style: TextStyle(color: Colors.blue, fontSize: fontSize),
      );
    }
    if (node is bool) {
      return SelectableText(
        node.toString(),
        style: TextStyle(color: Colors.orange, fontSize: fontSize),
      );
    }
    if (node is List) {
      if (node.isEmpty) {
        return Text(
          '[]',
          style: TextStyle(color: Colors.grey, fontSize: fontSize),
        );
      }
      return _CollapsibleNode(
        title: Text(
          '[${node.length}]',
          style: TextStyle(color: Colors.grey, fontSize: fontSize),
        ),
        children: node.asMap().entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${e.key}: ',
                  style: TextStyle(color: Colors.purple, fontSize: fontSize),
                ),
                Expanded(child: _buildNode(e.value)),
              ],
            ),
          );
        }).toList(),
      );
    }
    if (node is Map) {
      if (node.isEmpty) {
        return Text(
          '{}',
          style: TextStyle(color: Colors.grey, fontSize: fontSize),
        );
      }
      return _CollapsibleNode(
        title: Text(
          '{${node.length}}',
          style: TextStyle(color: Colors.grey, fontSize: fontSize),
        ),
        children: node.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${e.key}: ',
                  style: TextStyle(color: Colors.purple, fontSize: fontSize),
                ),
                Expanded(child: _buildNode(e.value)),
              ],
            ),
          );
        }).toList(),
      );
    }

    return SelectableText(
      node.toString(),
      style: TextStyle(fontSize: fontSize),
    );
  }
}

class _CollapsibleNode extends StatefulWidget {
  final Widget title;
  final List<Widget> children;

  const _CollapsibleNode({required this.title, required this.children});

  @override
  State<_CollapsibleNode> createState() => _CollapsibleNodeState();
}

class _CollapsibleNodeState extends State<_CollapsibleNode> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                size: 18,
                color: Colors.grey,
              ),
              widget.title,
            ],
          ),
        ),
        if (_expanded) ...widget.children,
      ],
    );
  }
}
