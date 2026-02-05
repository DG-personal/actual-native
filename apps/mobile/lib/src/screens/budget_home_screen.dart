import 'package:flutter/material.dart';

import '../actual_api.dart';
import '../budget_local.dart';
import '../sync/actual_sync_client.dart';
import '../sync/pb/sync.pb.dart' as pb;
import 'package:shared_preferences/shared_preferences.dart';

class BudgetHomeScreen extends StatefulWidget {
  const BudgetHomeScreen({
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
  State<BudgetHomeScreen> createState() => _BudgetHomeScreenState();
}

/// Minimal controller surface so the Dashboard tab can query data and trigger sync.
class BudgetHomeController {
  BudgetHomeController(this._state);

  final _BudgetHomeScreenState _state;

  Future<void> syncNow() => _state.syncNow();

  Future<DashboardData> loadDashboardData() => _state._loadDashboardData();

  Future<void> setPinnedCategoryIds(List<String> ids) => _state._setPinnedCategoryIds(ids);
}

class DashboardCategory {
  DashboardCategory({required this.id, required this.name, required this.spentThisMonthMilli});

  final String id;
  final String name;
  final int spentThisMonthMilli;
}

class DashboardTx {
  DashboardTx({
    required this.id,
    required this.date,
    required this.amountMilli,
    required this.description,
    this.accountName,
    this.categoryName,
  });

  final String id;
  final int date;
  final int amountMilli;
  final String description;
  final String? accountName;
  final String? categoryName;
}

class DashboardCategoryChoice {
  DashboardCategoryChoice({required this.id, required this.name});

  final String id;
  final String name;
}

class DashboardData {
  DashboardData({
    required this.pinnedCategoryIds,
    required this.pinnedCategories,
    required this.recentTransactions,
    required this.allCategories,
  });

  final List<String> pinnedCategoryIds;
  final List<DashboardCategory> pinnedCategories;
  final List<DashboardTx> recentTransactions;
  final List<DashboardCategoryChoice> allCategories;
}

class _BudgetHomeScreenState extends State<BudgetHomeScreen> {
  late final BudgetHomeController controller = BudgetHomeController(this);

  bool _loading = true;
  String? _error;
  LocalBudget? _budget;

  // MVP sync (unencrypted budgets only): track a simple `since` cursor.
  static const _zeroSince = '1970-01-01T00:00:00.000Z-0000-0000000000000000';
  String _since = _zeroSince;
  String? _syncInfo;

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

  Future<void> syncNow() async {
    if (widget.demoMode) {
      setState(() {
        _syncInfo = 'Demo mode (no server sync)';
      });
      return;
    }

    final token = widget.api.token;
    if (token == null) {
      setState(() => _syncInfo = 'Sync skipped: not logged in');
      return;
    }

    final budget = _budget;
    if (budget == null) {
      setState(() => _syncInfo = 'Sync skipped: local DB not open');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _syncInfo = 'Syncing…';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _since = prefs.getString('since:${widget.fileId}') ?? _zeroSince;

      final info = await widget.api.getUserFileInfo(fileId: widget.fileId);
      final data = info['data'] as Map<String, dynamic>?;
      final groupId = (data?['groupId'] as String?) ?? '';
      if (groupId.isEmpty) {
        throw Exception('Missing groupId');
      }

      final syncClient = ActualSyncClient(baseUrl: widget.api.baseUrl, token: token);
      final resp = await syncClient.sync(
        fileId: widget.fileId,
        groupId: groupId,
        since: _since,
      );

      final envs = resp.messages;
      // Advance since based on max timestamp seen.
      final maxTs = ActualSyncClient.maxTimestamp(envs);
      if (maxTs.isNotEmpty) {
        _since = maxTs;
        await prefs.setString('since:${widget.fileId}', _since);
      }

      // Apply messages to sqlite (unencrypted only)
      await _applyEnvelopesToSqlite(budget.db, envs);

      // Refresh views
      await _reloadFromDb();

      setState(() {
        _syncInfo = 'Sync ok: received ${envs.length} msgs; since=$_since';
      });
    } catch (e) {
      setState(() => _syncInfo = 'Sync error: $e');
    } finally {
      setState(() => _loading = false);
    }
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
      _syncInfo = null;
    });

    try {
      if (widget.demoMode) {
        _seedDemoData();
        setState(() => _loading = false);
        return;
      }

      // Load persisted `since` (manual sync uses this cursor).
      final prefs = await SharedPreferences.getInstance();
      _since = prefs.getString('since:${widget.fileId}') ?? _zeroSince;

      final budget = await BudgetLocal.downloadAndOpen(
        api: widget.api,
        fileId: widget.fileId,
        readOnly: false,
      );

      _budget = budget;
      await _reloadFromDb();

    } catch (e) {
      setState(() => _error = 'Failed to open budget: $e');
    } finally {
      setState(() => _loading = false);
    }
  }


  Future<void> _reloadFromDb() async {
    if (widget.demoMode) return;
    final db = _budget?.db;
    if (db == null) return;

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
      _accounts = accounts;
      _categoryGroups = groups;
      _categories = cats;
      _selectedAccountId = _selectedAccountId ?? (accounts.isNotEmpty ? accounts.first['id'] as String? : null);
    });

    if (_selectedAccountId != null) {
      await _loadTransactions(_selectedAccountId!);
    }
  }

  String _q(String ident) => '"${ident.replaceAll('"', '""')}"';

  Object? _decodeValue(String v) {
    if (v.startsWith('0:')) return null;
    if (v.startsWith('S:')) return v.substring(2);
    if (v.startsWith('N:')) {
      final n = num.tryParse(v.substring(2));
      if (n == null) return null;
      if (n is int) return n;
      if (n % 1 == 0) return n.toInt();
      return n;
    }
    return v;
  }

  Future<void> _applyEnvelopesToSqlite(
    dynamic db,
    List<pb.MessageEnvelope> envs,
  ) async {
    // Only supports unencrypted envelopes for MVP.
    await db.transaction((txn) async {
      for (final env in envs) {
        if (env.isEncrypted) continue;
        final msg = pb.Message.fromBuffer(env.content);
        final dataset = msg.dataset;
        if (dataset == 'prefs') continue;

        final rowId = msg.row;
        final col = msg.column;
        final val = _decodeValue(msg.value);

        final tableQ = _q(dataset);
        final colQ = _q(col);

        // Ensure row exists
        await txn.execute('INSERT OR IGNORE INTO $tableQ (id) VALUES (?)', [rowId]);
        // Apply update
        await txn.execute('UPDATE $tableQ SET $colQ = ? WHERE id = ?', [val, rowId]);
      }
    });
  }

  static String _pinsKey(String fileId) => 'pinnedCats:$fileId';

  Future<List<String>> _getPinnedCategoryIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pinsKey(widget.fileId)) ?? <String>[];
  }

  Future<void> _setPinnedCategoryIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final unique = ids.toSet().toList();
    unique.sort();
    await prefs.setStringList(_pinsKey(widget.fileId), unique);
  }

  int _monthStartInt(DateTime now) => (now.year * 10000) + (now.month * 100) + 1;

  int _monthEndInt(DateTime now) {
    final nextMonth = (now.month == 12) ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
    final lastDay = nextMonth.subtract(const Duration(days: 1));
    return (lastDay.year * 10000) + (lastDay.month * 100) + lastDay.day;
  }

  Future<DashboardData> _loadDashboardData() async {
    // Ensure base lists are loaded for the category picker.
    if (_categories.isEmpty && !widget.demoMode) {
      await _reloadFromDb();
    }

    // Demo mode: reuse seeded demo data.
    if (widget.demoMode) {
      final allCats = _categories
          .map((c) => DashboardCategoryChoice(id: c['id'] as String? ?? '', name: c['name'] as String? ?? ''))
          .where((c) => c.id.isNotEmpty)
          .toList();

      final pinnedIds = (await _getPinnedCategoryIds());
      final effectivePinned = pinnedIds.isNotEmpty ? pinnedIds : allCats.take(3).map((c) => c.id).toList();

      final pinned = effectivePinned
          .map((id) {
            final cat = _categories.firstWhere((c) => c['id'] == id, orElse: () => {'name': id});
            final name = (cat['name'] as String?) ?? id;
            final spent = _transactions
                .where((t) => t['category'] == id)
                .fold<int>(0, (sum, t) => sum + ((t['amount'] as num?)?.toInt() ?? 0));
            return DashboardCategory(id: id, name: name, spentThisMonthMilli: spent);
          })
          .toList();

      final recent = _transactions
          .take(15)
          .map((t) => DashboardTx(
                id: (t['id'] as String?) ?? '',
                date: (t['date'] as num?)?.toInt() ?? 0,
                amountMilli: (t['amount'] as num?)?.toInt() ?? 0,
                description: (t['description'] as String?) ?? '',
                categoryName: _categories
                    .firstWhere((c) => c['id'] == t['category'], orElse: () => const <String, Object?>{})['name'] as String?,
                accountName: null,
              ))
          .toList();

      return DashboardData(
        pinnedCategoryIds: effectivePinned,
        pinnedCategories: pinned,
        recentTransactions: recent,
        allCategories: allCats,
      );
    }

    final db = _budget?.db;
    if (db == null) {
      throw Exception('Local DB not open');
    }

    final allCatsRows = await db.rawQuery(
      'SELECT id, name FROM categories WHERE tombstone = 0 AND is_income = 0 ORDER BY sort_order',
    );
    final allCats = allCatsRows
        .map((r) => DashboardCategoryChoice(id: r['id'] as String, name: (r['name'] as String?) ?? ''))
        .toList();

    var pinnedIds = await _getPinnedCategoryIds();
    if (pinnedIds.isEmpty) {
      pinnedIds = allCats.take(5).map((c) => c.id).toList();
      // don't persist automatically; let the user edit/save
    }

    final now = DateTime.now();
    final start = _monthStartInt(now);
    final end = _monthEndInt(now);

    // Build a safe IN clause.
    final effectivePins = pinnedIds.where((id) => id.isNotEmpty).toList();
    final inClause = effectivePins.isEmpty ? 'NULL' : effectivePins.map((_) => '?').join(',');

    final pinnedRows = effectivePins.isEmpty
        ? <Map<String, Object?>>[]
        : await db.rawQuery(
            'SELECT c.id as id, c.name as name, COALESCE(SUM(t.amount), 0) as spent '
            'FROM categories c '
            'LEFT JOIN transactions t ON t.category = c.id AND t.tombstone = 0 AND t.date BETWEEN ? AND ? '
            'WHERE c.id IN ($inClause) '
            'GROUP BY c.id '
            'ORDER BY c.sort_order',
            [start, end, ...effectivePins],
          );

    final pinned = pinnedRows
        .map((r) => DashboardCategory(
              id: r['id'] as String,
              name: (r['name'] as String?) ?? '',
              spentThisMonthMilli: (r['spent'] as num?)?.toInt() ?? 0,
            ))
        .toList();

    final txRows = await db.rawQuery(
      'SELECT t.id as id, t.date as date, t.amount as amount, t.description as description, '
      'a.name as account_name, c.name as category_name '
      'FROM transactions t '
      'LEFT JOIN accounts a ON a.id = t.acct '
      'LEFT JOIN categories c ON c.id = t.category '
      'WHERE t.tombstone = 0 '
      'ORDER BY t.date DESC, t.sort_order DESC '
      'LIMIT 15',
    );

    final recent = txRows
        .map((r) => DashboardTx(
              id: r['id'] as String,
              date: (r['date'] as num?)?.toInt() ?? 0,
              amountMilli: (r['amount'] as num?)?.toInt() ?? 0,
              description: (r['description'] as String?) ?? '',
              accountName: r['account_name'] as String?,
              categoryName: r['category_name'] as String?,
            ))
        .toList();

    return DashboardData(
      pinnedCategoryIds: pinnedIds,
      pinnedCategories: pinned,
      recentTransactions: recent,
      allCategories: allCats,
    );
  }

  void _seedDemoData() {
    // IDs are arbitrary strings; in real budgets they are UUIDs.
    const checkingId = 'demo-checking';
    const savingsId = 'demo-savings';
    const cardId = 'demo-card';

    _accounts = [
      {
        'id': checkingId,
        'name': 'Checking',
        'type': 'depository',
        'balance_current': 2450000, // $2450.000
      },
      {
        'id': savingsId,
        'name': 'Savings',
        'type': 'depository',
        'balance_current': 12000000, // $12000.000
      },
      {
        'id': cardId,
        'name': 'Credit Card',
        'type': 'credit',
        'balance_current': -531250, // -$531.250
      },
    ];

    _categoryGroups = [
      {'id': 'cg-income', 'name': 'Income', 'sort_order': 1.0, 'is_income': 1},
      {'id': 'cg-bills', 'name': 'Bills', 'sort_order': 2.0, 'is_income': 0},
      {'id': 'cg-frequent', 'name': 'Frequent', 'sort_order': 3.0, 'is_income': 0},
      {'id': 'cg-fun', 'name': 'Fun', 'sort_order': 4.0, 'is_income': 0},
    ];

    _categories = [
      {'id': 'c-paycheck', 'name': 'Paycheck', 'cat_group': 'cg-income', 'sort_order': 1.0, 'is_income': 1},
      {'id': 'c-rent', 'name': 'Rent', 'cat_group': 'cg-bills', 'sort_order': 2.0, 'is_income': 0},
      {'id': 'c-electric', 'name': 'Electric', 'cat_group': 'cg-bills', 'sort_order': 3.0, 'is_income': 0},
      {'id': 'c-groceries', 'name': 'Groceries', 'cat_group': 'cg-frequent', 'sort_order': 4.0, 'is_income': 0},
      {'id': 'c-gas', 'name': 'Gas', 'cat_group': 'cg-frequent', 'sort_order': 5.0, 'is_income': 0},
      {'id': 'c-restaurants', 'name': 'Restaurants', 'cat_group': 'cg-frequent', 'sort_order': 6.0, 'is_income': 0},
      {'id': 'c-entertainment', 'name': 'Entertainment', 'cat_group': 'cg-fun', 'sort_order': 7.0, 'is_income': 0},
    ];

    // date is int YYYYMMDD, amount is milliunits.
    _selectedAccountId = checkingId;
    _transactions = [
      {'id': 't1', 'date': 20260201, 'amount': 4500000, 'description': 'Paycheck', 'category': 'c-paycheck'},
      {'id': 't2', 'date': 20260202, 'amount': -1500000, 'description': 'Rent', 'category': 'c-rent'},
      {'id': 't3', 'date': 20260203, 'amount': -112450, 'description': 'Groceries', 'category': 'c-groceries'},
      {'id': 't4', 'date': 20260204, 'amount': -45000, 'description': 'Gas', 'category': 'c-gas'},
      {'id': 't5', 'date': 20260205, 'amount': -58999, 'description': 'Dinner', 'category': 'c-restaurants'},
      {'id': 't6', 'date': 20260206, 'amount': -14900, 'description': 'Movie rental', 'category': 'c-entertainment'},
      {'id': 't7', 'date': 20260207, 'amount': -89100, 'description': 'Electric bill', 'category': 'c-electric'},
    ];
  }

  final Map<String, Set<String>> _tableColumnsCache = {};

  Future<bool> _tableExists(dynamic db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ? LIMIT 1",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> _tableColumns(dynamic db, String table) async {
    final cached = _tableColumnsCache[table];
    if (cached != null) return cached;

    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final cols = <String>{
      for (final r in rows) (r['name'] as String?) ?? '',
    }..remove('');

    _tableColumnsCache[table] = cols;
    return cols;
  }

  Future<void> _loadTransactions(String accountId) async {
    if (widget.demoMode) {
      setState(() => _selectedAccountId = accountId);
      return;
    }

    final db = _budget?.db;
    if (db == null) return;

    final txCols = await _tableColumns(db, 'transactions');

    final payeeCol = txCols.contains('payee')
        ? 'payee'
        : (txCols.contains('payee_id') ? 'payee_id' : null);

    final hasCleared = txCols.contains('cleared');
    final hasReconciled = txCols.contains('reconciled');

    final hasPayees = payeeCol != null && await _tableExists(db, 'payees');

    final select = <String>[
      't.id as id',
      't.date as date',
      't.amount as amount',
      't.description as description',
      't.notes as notes',
      't.category as category',
      't.acct as acct',
      'a.name as account_name',
      'c.name as category_name',
      if (payeeCol != null) 't.$payeeCol as payee_id',
      if (hasPayees) 'p.name as payee_name',
      if (hasCleared) 't.cleared as cleared',
      if (hasReconciled) 't.reconciled as reconciled',
    ].join(', ');

    final joins = <String>[
      'LEFT JOIN accounts a ON a.id = t.acct',
      'LEFT JOIN categories c ON c.id = t.category',
      if (hasPayees) 'LEFT JOIN payees p ON p.id = t.$payeeCol',
    ].join(' ');

    final tx = await db.rawQuery(
      'SELECT $select '
      'FROM transactions t '
      '$joins '
      'WHERE t.tombstone = 0 AND t.acct = ? '
      'ORDER BY t.date DESC, t.sort_order DESC '
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
                      if (_syncInfo != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            _syncInfo!,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
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

              final categoryName = (t['category_name'] as String?) ??
                  _categories
                      .firstWhere(
                        (c) => c['id'] == t['category'],
                        orElse: () => const <String, Object?>{},
                      )['name'] as String?;

              final payeeName = (t['payee_name'] as String?);

              final cleared = (t['cleared'] as num?)?.toInt();
              final reconciled = (t['reconciled'] as num?)?.toInt();

              final flags = <String>[];
              if (reconciled != null && reconciled != 0) flags.add('R');
              if (cleared != null && cleared != 0) flags.add('C');

              final subtitleParts = <String>[date];
              if (payeeName != null && payeeName.isNotEmpty) subtitleParts.add(payeeName);
              if (categoryName != null && categoryName.isNotEmpty) subtitleParts.add(categoryName);
              if (flags.isNotEmpty) subtitleParts.add(flags.join(','));

              return ListTile(
                title: Text(desc.isEmpty ? '(no description)' : desc),
                subtitle: Text(subtitleParts.join(' • ')),
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
