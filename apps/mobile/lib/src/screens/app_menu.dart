import 'package:flutter/material.dart';

import '../actual_api.dart';
import 'budget_select_screen.dart';
import 'root_screen.dart';

enum _AppMenuAction { switchBudget, logout }

class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key, required this.api, this.icon});

  final ActualApi api;
  final Widget? icon;

  Future<void> _switchBudget(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final budgets = await api.listUserFiles();
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BudgetSelectScreen(api: api, budgets: budgets),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to load budgets: $e')),
      );
    }
  }

  void _logout(BuildContext context) {
    api.token = null;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AppMenuAction>(
      icon: icon ?? const Icon(Icons.more_vert),
      onSelected: (v) {
        switch (v) {
          case _AppMenuAction.switchBudget:
            _switchBudget(context);
          case _AppMenuAction.logout:
            _logout(context);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _AppMenuAction.switchBudget,
          child: ListTile(
            leading: Icon(Icons.swap_horiz),
            title: Text('Switch budget'),
          ),
        ),
        PopupMenuItem(
          value: _AppMenuAction.logout,
          child: ListTile(leading: Icon(Icons.logout), title: Text('Logout')),
        ),
      ],
    );
  }
}
