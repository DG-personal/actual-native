import 'package:flutter/material.dart';

import '../actual_api.dart';
import 'budget_dashboard_screen.dart';
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
  final ValueNotifier<BudgetHomeController?> _controller = ValueNotifier(null);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      BudgetDashboardScreen(
        api: widget.api,
        name: widget.name,
        controllerListenable: _controller,
      ),

      // Existing budget view (accounts/transactions/budget)
      BudgetHomeScreen(
        api: widget.api,
        fileId: widget.fileId,
        name: widget.name,
        demoMode: widget.demoMode,
        controllerNotifier: _controller,
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
