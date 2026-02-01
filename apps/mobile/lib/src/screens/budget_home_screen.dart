import 'package:flutter/material.dart';

import '../actual_api.dart';
import '../budget_local.dart';

class BudgetHomeScreen extends StatefulWidget {
  const BudgetHomeScreen({
    super.key,
    required this.api,
    required this.fileId,
    required this.name,
  });

  final ActualApi api;
  final String fileId;
  final String name;

  @override
  State<BudgetHomeScreen> createState() => _BudgetHomeScreenState();
}

class _BudgetHomeScreenState extends State<BudgetHomeScreen> {
  bool _loading = true;
  String? _error;
  LocalBudget? _budget;

  List<Map<String, Object?>> _accounts = [];
  List<Map<String, Object?>> _categories = [];
  List<Map<String, Object?>> _categoryGroups = [];

  String? _selectedAccountId;
  List<Map<String, Object?>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _budget?.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final budget = await BudgetLocal.downloadAndOpen(
        api: widget.api,
        fileId: widget.fileId,
      );

      final db = budget.db;
      final accounts = await db.rawQuery(
        'SELECT id, name, type, offbudget, closed, balance_current, balance_available '
        'FROM accounts '
        'ORDER BY name',
      );

      final groups = await db.rawQuery(
        'SELECT id, name, sort_order, is_income '
        'FROM category_groups '
        'WHERE tombstone = 0 '
        'ORDER BY sort_order',
      );

      final cats = await db.rawQuery(
        'SELECT id, name, cat_group, sort_order, is_income '
        'FROM categories '
        'WHERE tombstone = 0 '
        'ORDER BY sort_order',
      );

      setState(() {
        _budget = budget;
        _accounts = accounts;
        _categoryGroups = groups;
        _categories = cats;
        _selectedAccountId = accounts.isNotEmpty ? accounts.first['id'] as String? : null;
      });

      if (_selectedAccountId != null) {
        await _loadTransactions(_selectedAccountId!);
      }
    } catch (e) {
      setState(() => _error = 'Failed to open budget: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadTransactions(String accountId) async {
    final db = _budget?.db;
    if (db == null) return;

    final tx = await db.rawQuery(
      'SELECT id, date, amount, description, notes, category '
      'FROM transactions '
      'WHERE tombstone = 0 AND acct = ? '
      'ORDER BY date DESC, sort_order DESC '
      'LIMIT 200',
      [accountId],
    );

    setState(() {
      _selectedAccountId = accountId;
      _transactions = tx;
    });
  }

  String _fmtMoney(Object? v) {
    if (v == null) return '';
    final milli = (v as num).toInt();
    final sign = milli < 0 ? '-' : '';
    final abs = milli.abs();
    final dollars = abs ~/ 1000;
    final frac = (abs % 1000).toString().padLeft(3, '0');
    return '$sign\$$dollars.$frac';
  }

  String _fmtDate(Object? v) {
    if (v == null) return '';
    final n = (v as num).toInt();
    final y = n ~/ 10000;
    final m = (n ~/ 100) % 100;
    final d = n % 100;
    return '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-download',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Accounts'),
                          Tab(text: 'Transactions'),
                          Tab(text: 'Budget'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildAccounts(),
                            _buildTransactions(),
                            _buildBudget(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAccounts() {
    return ListView.separated(
      itemCount: _accounts.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final a = _accounts[i];
        final id = a['id'] as String?;
        final name = (a['name'] as String?) ?? '(unnamed)';
        final bal = _fmtMoney(a['balance_current']);
        return ListTile(
          title: Text(name),
          subtitle: Text((a['type'] as String?) ?? ''),
          trailing: Text(bal),
          onTap: id == null
              ? null
              : () async {
                  final controller = DefaultTabController.of(context);
                  await _loadTransactions(id);
                  if (!mounted) return;
                  controller.animateTo(1);
                },
        );
      },
    );
  }

  Widget _buildTransactions() {
    final selected = _selectedAccountId;
    final header = selected == null
        ? 'No account selected'
        : 'Account: ${_accounts.firstWhere((a) => a['id'] == selected, orElse: () => {'name': selected})['name']}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(header, style: const TextStyle(color: Colors.grey)),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: _transactions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = _transactions[i];
              final desc = (t['description'] as String?) ?? '';
              final date = _fmtDate(t['date']);
              final amt = _fmtMoney(t['amount']);
              return ListTile(
                title: Text(desc.isEmpty ? '(no description)' : desc),
                subtitle: Text(date),
                trailing: Text(amt),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBudget() {
    // Group categories by cat_group.
    final byGroup = <String, List<Map<String, Object?>>>{};
    for (final c in _categories) {
      final g = (c['cat_group'] as String?) ?? 'ungrouped';
      byGroup.putIfAbsent(g, () => []).add(c);
    }

    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Category Groups', style: TextStyle(color: Colors.grey)),
        ),
        for (final g in _categoryGroups) ...[
          ListTile(
            title: Text((g['name'] as String?) ?? ''),
          ),
          ...((byGroup[(g['id'] as String?) ?? ''] ?? const <Map<String, Object?>>[]).map(
            (c) => Padding(
              padding: const EdgeInsets.only(left: 20),
              child: ListTile(
                dense: true,
                title: Text((c['name'] as String?) ?? ''),
              ),
            ),
          )),
          const Divider(height: 1),
        ],
      ],
    );
  }
}
