import 'package:flutter/material.dart';

import '../actual_api.dart';

class BudgetDetailScreen extends StatefulWidget {
  const BudgetDetailScreen({
    super.key,
    required this.api,
    required this.fileId,
    required this.name,
  });

  final ActualApi api;
  final String fileId;
  final String name;

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _info;
  int? _downloadBytes;

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final info = await widget.api.getUserFileInfo(fileId: widget.fileId);
      setState(() => _info = info);
    } catch (e) {
      setState(() => _error = 'Failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    setState(() {
      _loading = true;
      _error = null;
      _downloadBytes = null;
    });

    try {
      final bytes = await widget.api.downloadUserFileSize(fileId: widget.fileId);
      setState(() => _downloadBytes = bytes);
    } catch (e) {
      setState(() => _error = 'Download failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final data = info?['data'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('fileId: ${widget.fileId}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh metadata'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _loading ? null : _download,
              icon: const Icon(Icons.download),
              label: const Text('Download file (measure size)'),
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            if (_downloadBytes != null) ...[
              const SizedBox(height: 12),
              Text('Downloaded bytes: $_downloadBytes'),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: data == null
                      ? const Text('No metadata loaded yet.')
                      : SingleChildScrollView(
                          child: Text(data.toString()),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
