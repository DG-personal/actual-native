import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Actual Native',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ActualHomePage(),
    );
  }
}

class ActualHomePage extends StatefulWidget {
  const ActualHomePage({super.key});

  @override
  State<ActualHomePage> createState() => _ActualHomePageState();
}

class _ActualHomePageState extends State<ActualHomePage> {
  static const String defaultBaseUrl = 'http://192.168.1.182:5006';

  final _baseUrlController = TextEditingController(text: defaultBaseUrl);
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _serverInfo;

  Future<void> _fetchServerInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('${_baseUrlController.text}/health');
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() => _serverInfo = data);
    } catch (e) {
      setState(() => _error = 'Failed to reach server: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _serverInfo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actual Native'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Connect to your Actual server',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Server base URL',
                hintText: 'http://192.168.1.182:5006',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _fetchServerInfo,
              icon: const Icon(Icons.sync),
              label: const Text('Check server'),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            if (info != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Server response',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('status: ${info['status'] ?? 'unknown'}'),
                      if (info.containsKey('details'))
                        Text('details: ${info['details']}'),
                      if (info.containsKey('version'))
                        Text('version: ${info['version']}'),
                    ],
                  ),
                ),
              ),
            ],
            const Spacer(),
            Text(
              'Next: auth, budgets, accounts, transactions',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
