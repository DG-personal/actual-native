import 'package:flutter/material.dart';

import '../actual_api.dart';
import 'budget_home_screen.dart';

class BudgetShellScreen extends StatefulWidget {
  const BudgetShellScreen({
    super.key,
    required this.api,
    required this.fileId,
    required this.name,
    this.demoMode = false,
  });

  final ActualApi api;
  final String fileId;
  final String name;
  final bool demoMode;

  @override
  State<BudgetShellScreen> createState() => _BudgetShellScreenState();
}

class _BudgetShellScreenState extends State<BudgetShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      // Dashboard (placeholder for now)
      _DashboardPlaceholder(name: widget.name),

      // Existing budget view (accounts/transactions/budget)
      BudgetHomeScreen(
        api: widget.api,
        fileId: widget.fileId,
        name: widget.name,
        demoMode: widget.demoMode,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
        ],
      ),
    );
  }
}

class _DashboardPlaceholder extends StatelessWidget {
  const _DashboardPlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Dashboard (WIP)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Next: pinned budget categories + recent transactions.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Pinned categories (placeholder)'),
                    SizedBox(height: 6),
                    Text('- Groceries'),
                    Text('- Rent'),
                    Text('- Gas'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Recent transactions (placeholder)'),
                    SizedBox(height: 6),
                    Text('• Groceries  -\$112.45'),
                    Text('• Dinner     -\$58.999'),
                    Text('• Paycheck   +\$4500.000'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
