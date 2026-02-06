import 'package:flutter/material.dart';

import '../actual_api.dart';
import 'budget_shell_screen.dart';
import 'root_screen.dart';

class BudgetSelectScreen extends StatelessWidget {
  const BudgetSelectScreen({
    super.key,
    required this.api,
    required this.budgets,
  });

  final ActualApi api;
  final List<dynamic> budgets;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose budget'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () {
              api.token = null;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RootScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => BudgetShellScreen(
                      api: api,
                      fileId: 'demo',
                      name: 'Demo Budget',
                      demoMode: true,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Open Demo Budget (local data)'),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: budgets.length,
              itemBuilder: (context, idx) {
                final b = budgets[idx] as Map<String, dynamic>;
                final name = (b['name'] as String?) ?? '(unnamed)';
                final fileId = (b['fileId'] as String?) ?? '';
                final deleted = (b['deleted'] as int?) == 1;

                return ListTile(
                  title: Text(name),
                  subtitle: Text(fileId),
                  trailing: deleted
                      ? const Text('DELETED')
                      : const Icon(Icons.chevron_right),
                  onTap: deleted
                      ? null
                      : () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => BudgetShellScreen(
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
    );
  }
}
