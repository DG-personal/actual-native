import 'package:flutter/material.dart';

import 'budget_home_screen.dart';

class BudgetDashboardScreen extends StatefulWidget {
  const BudgetDashboardScreen({
    super.key,
    required this.name,
    required this.budgetHomeKey,
  });

  final String name;
  final GlobalKey budgetHomeKey;

  @override
  State<BudgetDashboardScreen> createState() => _BudgetDashboardScreenState();
}

class _BudgetDashboardScreenState extends State<BudgetDashboardScreen> {
  Future<DashboardData>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  BudgetHomeController? _controller() {
    final s = widget.budgetHomeKey.currentState;
    if (s == null) return null;
    // ignore: avoid_dynamic_calls
    return (s as dynamic).controller as BudgetHomeController?;
  }

  void _refresh() {
    final c = _controller();
    setState(() {
      _future = c?.loadDashboardData();
    });
  }

  Future<void> _syncNow() async {
    final c = _controller();
    if (c == null) return;
    await c.syncNow();
    if (!mounted) return;
    _refresh();
  }

  Future<void> _editPins(DashboardData data) async {
    final c = _controller();
    if (c == null) return;

    final allCats = data.allCategories;
    final pinned = {...data.pinnedCategoryIds};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    const Text('Pinned categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: allCats.length,
                        itemBuilder: (context, i) {
                          final cat = allCats[i];
                          final id = cat.id;
                          final checked = pinned.contains(id);
                          return CheckboxListTile(
                            value: checked,
                            title: Text(cat.name),
                            onChanged: (v) {
                              setSheetState(() {
                                if (v == true) {
                                  pinned.add(id);
                                } else {
                                  pinned.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                await c.setPinnedCategoryIds(pinned.toList());
                                if (context.mounted) Navigator.of(context).pop();
                              },
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    if (!mounted) return;
    _refresh();
  }

  String _fmtMoney(int milli) {
    final sign = milli < 0 ? '-' : '';
    final abs = milli.abs();
    final dollars = abs ~/ 1000;
    final frac = (abs % 1000).toString().padLeft(3, '0');
    return '$sign\$$dollars.$frac';
  }

  String _fmtDate(int yyyymmdd) {
    final y = yyyymmdd ~/ 10000;
    final m = (yyyymmdd ~/ 100) % 100;
    final d = yyyymmdd % 100;
    return '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            onPressed: c == null ? null : _syncNow,
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Now',
          ),
          IconButton(
            onPressed: c == null ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: c == null
          ? const Center(child: Text('Budget not loaded yet'))
          : FutureBuilder<DashboardData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Dashboard error: ${snap.error}', style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _refresh, child: const Text('Retry')),
                      ],
                    ),
                  );
                }

                final data = snap.data;
                if (data == null) {
                  return const Center(child: Text('No data'));
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pinned categories (this month)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _editPins(data),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (data.pinnedCategories.isEmpty)
                      const Text('No pinned categories yet.'),
                    for (final p in data.pinnedCategories)
                      Card(
                        child: ListTile(
                          title: Text(p.name),
                          trailing: Text(_fmtMoney(p.spentThisMonthMilli)),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text('Recent transactions', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (data.recentTransactions.isEmpty)
                      const Text('No transactions yet.'),
                    for (final t in data.recentTransactions)
                      Card(
                        child: ListTile(
                          title: Text(t.description.isEmpty ? '(no description)' : t.description),
                          subtitle: Text(
                            '${_fmtDate(t.date)}'
                            '${t.categoryName == null ? '' : ' • ${t.categoryName}'}'
                            '${t.accountName == null ? '' : ' • ${t.accountName}'}',
                          ),
                          trailing: Text(_fmtMoney(t.amountMilli)),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
