import 'package:flutter/material.dart';

import 'src/actual_api.dart';
import 'src/screens/budget_detail_screen.dart';

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
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  // Android emulator reaches the host machine via 10.0.2.2
  final _baseUrlController = TextEditingController(text: 'http://10.0.2.2:5006');
  final _passwordController = TextEditingController();

  ActualApi? _api;
  bool _loading = false;
  String? _error;

  bool _bootstrapped = true;
  List<dynamic> _budgets = [];

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
      _budgets = [];
    });

    try {
      final api = ActualApi(baseUrl: _baseUrlController.text.trim());
      final info = await api.needsBootstrap();
      final data = info['data'] as Map<String, dynamic>?;
      final bootstrapped = data?['bootstrapped'] as bool? ?? true;
      setState(() {
        _api = api;
        _bootstrapped = bootstrapped;
      });
    } catch (e) {
      setState(() => _error = 'Connect failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _bootstrapIfNeeded() async {
    final api = _api;
    if (api == null) return;
    final pwd = _passwordController.text;
    if (pwd.isEmpty) {
      setState(() => _error = 'Enter a password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await api.bootstrap(password: pwd);
      final info = await api.needsBootstrap();
      final data = info['data'] as Map<String, dynamic>?;
      final bootstrapped = data?['bootstrapped'] as bool? ?? true;
      setState(() => _bootstrapped = bootstrapped);
    } catch (e) {
      setState(() => _error = 'Bootstrap failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loginAndLoadBudgets() async {
    final api = _api;
    if (api == null) return;
    final pwd = _passwordController.text;
    if (pwd.isEmpty) {
      setState(() => _error = 'Enter a password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _budgets = [];
    });

    try {
      await api.login(password: pwd);
      final budgets = await api.listUserFiles();
      setState(() => _budgets = budgets);
    } catch (e) {
      setState(() => _error = 'Login/load failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = _api;

    return Scaffold(
      appBar: AppBar(title: const Text('Actual Native')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Actual server URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _loading ? null : _connect,
              child: const Text('Connect'),
            ),
            const SizedBox(height: 12),
            if (api != null) ...[
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              if (!_bootstrapped)
                FilledButton.icon(
                  onPressed: _loading ? null : _bootstrapIfNeeded,
                  icon: const Icon(Icons.construction),
                  label: const Text('Bootstrap server (set password)'),
                ),
              FilledButton.icon(
                onPressed: _loading ? null : _loginAndLoadBudgets,
                icon: const Icon(Icons.login),
                label: const Text('Login + Load Budgets'),
              ),
            ],
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _budgets.length,
                itemBuilder: (context, idx) {
                  final b = _budgets[idx] as Map<String, dynamic>;
                  final name = (b['name'] as String?) ?? '(unnamed)';
                  final fileId = (b['fileId'] as String?) ?? '';
                  final deleted = (b['deleted'] as int?) == 1;
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(fileId),
                    trailing: deleted ? const Text('DELETED') : const Icon(Icons.chevron_right),
                    onTap: deleted
                        ? null
                        : () {
                            final api = _api;
                            if (api == null) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BudgetDetailScreen(
                                  api: api,
                                  fileId: fileId,
                                  name: name,
                                ),
                              ),
                            );
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
