import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const _appScheme = 'actualnative';
  static const _appHost = 'callback';
  static const _openIdCbPath = '/openid-cb';

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  // LAN is the default for real devices on your network.
  // Android emulator reaches the host machine via 10.0.2.2
  final _baseUrlController = TextEditingController(text: 'http://192.168.1.182:5006');
  final _serverHint = 'LAN: http://192.168.1.182:5006 | Android emulator: http://10.0.2.2:5006';
  final _passwordController = TextEditingController();

  ActualApi? _api;
  bool _loading = false;
  String? _error;

  bool _bootstrapped = true;
  List<dynamic> _budgets = [];

  String _openIdReturnUrlBase() {
    // Server will append `/openid-cb?token=...` to this.
    return '$_appScheme://$_appHost';
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    // Expect: actualnative://callback/openid-cb?token=...
    if (uri.scheme != _appScheme) return;
    if (uri.host != _appHost) return;
    if (uri.path != _openIdCbPath) return;

    final t = uri.queryParameters['token'];
    if (t == null || t.isEmpty) return;

    final api = _api;
    if (api == null) {
      setState(() => _error = 'Received OpenID token but API not connected yet');
      return;
    }

    api.setToken(t);
    try {
      final budgets = await api.listUserFiles();
      setState(() => _budgets = budgets);
    } catch (e) {
      setState(() => _error = 'OpenID token received, but loading budgets failed: $e');
    }
  }

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

  Future<void> _loginWithOpenId() async {
    final api = _api;
    if (api == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authUrl = await api.startOpenIdLogin(
        returnUrl: _openIdReturnUrlBase(),
        // Some server setups require password during OpenID initiation.
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
      );

      final uri = Uri.parse(authUrl);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        throw Exception('Failed to launch browser');
      }
    } catch (e) {
      setState(() => _error = 'OpenID start failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();

    // Listen for deep links (OpenID callback)
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleIncomingUri(uri);
      },
      onError: (err) {
        // Non-fatal; we can still use password login.
        // ignore: avoid_print
        print('app_links error: $err');
      },
    );

    // If app was started via a link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleIncomingUri(uri);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _baseUrlController.dispose();
    _passwordController.dispose();
    super.dispose();
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
              decoration: InputDecoration(
                labelText: 'Actual server URL',
                helperText: _serverHint,
                border: const OutlineInputBorder(),
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
                label: const Text('Login + Load Budgets (password)'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _loginWithOpenId,
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Login with Google (OpenID)'),
              ),
              const SizedBox(height: 6),
              Text(
                'OpenID callback: ${_openIdReturnUrlBase()}$_openIdCbPath',
                style: const TextStyle(color: Colors.grey),
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
