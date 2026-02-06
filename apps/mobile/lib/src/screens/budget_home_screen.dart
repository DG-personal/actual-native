import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../actual_api.dart';
import '../budget_local.dart';
import 'app_menu.dart';
import '../sync/actual_sync_client.dart';
import '../sync/pb/sync.pb.dart' as pb;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BudgetHomeScreen extends StatefulWidget {
  const BudgetHomeScreen({
    super.key,
    required this.api,
    required this.fileId,
    required this.name,
    this.demoMode = false,
    required this.controllerNotifier,
  });

  final ActualApi api;
  final String fileId;
  final String name;
  final bool demoMode;
  final ValueNotifier<BudgetHomeController?> controllerNotifier;

  @override
  State<BudgetHomeScreen> createState() => _BudgetHomeScreenState();
}

/// Minimal controller surface so the Dashboard tab can query data and trigger sync.
class BudgetHomeController {
  BudgetHomeController(this._state);

  // Intentionally `dynamic` so we don't expose a private State type in a public API.
  final dynamic _state;

  bool get syncing => _state._syncing;
  DateTime? get lastSyncAt => _state._lastSyncAt;
  String? get lastSyncError => _state._lastSyncError;

  Future<void> syncNow() => _state.syncNow();

  Future<DashboardData> loadDashboardData() => _state.loadDashboardData();

  Future<void> setPinnedCategoryIds(List<String> ids) =>
      _state.setPinnedCategoryIds(ids);
}

class DashboardCategory {
  DashboardCategory({
    required this.id,
    required this.name,
    required this.spentThisMonthMilli,
  });

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

class _SyncEnvPayload {
  const _SyncEnvPayload({required this.isEncrypted, required this.content});

  final bool isEncrypted;
  final Uint8List content;
}

class _SyncUpdate {
  const _SyncUpdate({
    required this.dataset,
    required this.rowId,
    required this.column,
    required this.value,
  });

  final String dataset;
  final String rowId;
  final String column;
  final Object? value;
}

class _BudgetHomeScreenState extends State<BudgetHomeScreen> {
  late final BudgetHomeController controller = BudgetHomeController(this);

  bool _loading = true;
  String? _error;
  LocalBudget? _budget;

  // MVP sync (unencrypted budgets only): track a simple `since` cursor.
  static const _zeroSince = '1970-01-01T00:00:00.000Z-0000-0000000000000000';
  String _since = _zeroSince;

  bool _syncing = false;
  DateTime? _lastSyncAt;
  String? _lastSyncError;

  List<Map<String, Object?>> _accounts = [];
  List<Map<String, Object?>> _categories = [];
  List<Map<String, Object?>> _categoryGroups = [];

  String? _selectedAccountId;
  List<Map<String, Object?>> _transactions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controllerNotifier.value = controller;
    });
    _load();
  }

  static String _sinceKey(String fileId) => 'since:$fileId';
  static String _lastSyncAtKey(String fileId) => 'lastSyncAt:$fileId';
  static String _lastSyncErrorKey(String fileId) => 'lastSyncError:$fileId';

  Future<void> _loadSyncMeta() async {
    final prefs = await SharedPreferences.getInstance();
    _since = prefs.getString(_sinceKey(widget.fileId)) ?? _zeroSince;
    final lastMs = prefs.getInt(_lastSyncAtKey(widget.fileId));
    _lastSyncAt = lastMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastMs);
    _lastSyncError = prefs.getString(_lastSyncErrorKey(widget.fileId));
  }

  Future<void> syncNow() async {
    if (widget.demoMode) {
      return;
    }

    final token = widget.api.token;
    if (token == null) {
      setState(() => _lastSyncError = 'Not logged in');
      return;
    }

    final budget = _budget;
    if (budget == null) {
      setState(() => _lastSyncError = 'Local DB not open');
      return;
    }

    setState(() {
      _syncing = true;
      _lastSyncError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _since = prefs.getString(_sinceKey(widget.fileId)) ?? _zeroSince;

      final info = await widget.api.getUserFileInfo(fileId: widget.fileId);
      final data = info['data'] as Map<String, dynamic>?;
      final groupId = (data?['groupId'] as String?) ?? '';
      if (groupId.isEmpty) {
        throw Exception('Missing groupId');
      }

      final syncClient = ActualSyncClient(
        baseUrl: widget.api.baseUrl,
        token: token,
      );

      var totalEnvelopes = 0;
      var loops = 0;
      var retriedFromZero = false;
      while (true) {
        loops++;
        if (loops > 50) {
          throw Exception('Sync aborted: too many pages (possible loop)');
        }

        final prevSince = _since;
        final resp = await syncClient.sync(
          fileId: widget.fileId,
          groupId: groupId,
          since: _since,
        );

        final envs = resp.messages;

        // If server says "no updates" but our local DB is empty, force a full
        // resync from zero. This happens if the since cursor was persisted
        // incorrectly from a prior buggy run.
        if (envs.isEmpty && !retriedFromZero) {
          final acctCountRows = await budget.db.rawQuery(
            'SELECT COUNT(*) as c FROM accounts',
          );
          final txCountRows = await budget.db.rawQuery(
            'SELECT COUNT(*) as c FROM transactions',
          );
          final acctCount = (acctCountRows.first['c'] as num?)?.toInt() ?? 0;
          final txCount = (txCountRows.first['c'] as num?)?.toInt() ?? 0;

          if (acctCount == 0 && txCount == 0 && _since != _zeroSince) {
            retriedFromZero = true;
            _since = _zeroSince;
            await prefs.setString(_sinceKey(widget.fileId), _since);
            continue;
          }
        }

        if (envs.isEmpty) break;

        totalEnvelopes += envs.length;

        // Advance since based on max timestamp seen.
        final maxTs = ActualSyncClient.maxTimestamp(envs);
        if (maxTs.isNotEmpty && maxTs != _since) {
          _since = maxTs;
          await prefs.setString(_sinceKey(widget.fileId), _since);
        }

        // Decode + apply messages to sqlite (unencrypted only)
        final updates = await _decodeEnvelopesInIsolate(envs);
        await _applyUpdatesToSqlite(budget.db, updates);

        // If timestamps didn't advance, bail to avoid infinite loops.
        if (maxTs.isEmpty || maxTs == prevSince) break;

        // Best-effort: let the UI breathe between pages.
        if (mounted) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      }

      // Refresh views
      await _reloadFromDb();

      // Debug: show counts so we can verify sqlite is actually getting populated.
      final acctCountRows = await budget.db.rawQuery(
        'SELECT COUNT(*) as c FROM accounts',
      );
      final txCountRows = await budget.db.rawQuery(
        'SELECT COUNT(*) as c FROM transactions',
      );
      final acctCount = (acctCountRows.first['c'] as num?)?.toInt() ?? 0;
      final txCount = (txCountRows.first['c'] as num?)?.toInt() ?? 0;

      final now = DateTime.now();
      _lastSyncAt = now;
      await prefs.setInt(
        _lastSyncAtKey(widget.fileId),
        now.millisecondsSinceEpoch,
      );
      await prefs.remove(_lastSyncErrorKey(widget.fileId));

      // Ensure dashboard gets a refresh after sync.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controllerNotifier.value = controller;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync ok: $totalEnvelopes updates • accounts=$acctCount • tx=$txCount',
            ),
          ),
        );
      }
    } catch (e) {
      _lastSyncError = e.toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncErrorKey(widget.fileId), _lastSyncError!);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync failed: $_lastSyncError')));
      }
    } finally {
      setState(() => _syncing = false);
    }
  }

  @override
  void dispose() {
    // Keep the local DB open while the budget shell is alive (prevents re-sync on tab switches).
    // On budget switch/logout, the whole shell is torn down.
    widget.controllerNotifier.value = null;
    super.dispose();
  }

  static String _hydratedKey(String fileId) => 'hydrated:$fileId';

  Future<Map<String, int>> _dbCounts(dynamic db) async {
    final acctRows = await db.rawQuery('SELECT COUNT(*) as c FROM accounts');
    final txRows = await db.rawQuery('SELECT COUNT(*) as c FROM transactions');
    final zbRows = await db.rawQuery('SELECT COUNT(*) as c FROM zero_budgets');

    return {
      'accounts': (acctRows.first['c'] as num?)?.toInt() ?? 0,
      'transactions': (txRows.first['c'] as num?)?.toInt() ?? 0,
      'zero_budgets': (zbRows.first['c'] as num?)?.toInt() ?? 0,
    };
  }

  Future<void> _hydrateBudgetIfNeeded() async {
    if (widget.demoMode) return;

    final budget = _budget;
    if (budget == null) return;

    final token = widget.api.token;
    if (token == null) return;

    final prefs = await SharedPreferences.getInstance();
    final hydrated = prefs.getBool(_hydratedKey(widget.fileId)) ?? false;

    final counts = await _dbCounts(budget.db);
    final looksEmpty = counts['accounts'] == 0 && counts['transactions'] == 0;
    final missingBudgetData = (counts['zero_budgets'] ?? 0) == 0;

    if (hydrated && !looksEmpty && !missingBudgetData) {
      return;
    }

    // Full hydrate: replay from zero until server returns no more envelopes.
    setState(() {
      _syncing = true;
      _lastSyncError = null;
    });

    try {
      // Nudge the dashboard to refresh once the budget screen is mounted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controllerNotifier.value = controller;
      });

      final info = await widget.api.getUserFileInfo(fileId: widget.fileId);
      final data = info['data'] as Map<String, dynamic>?;
      final groupId = (data?['groupId'] as String?) ?? '';
      if (groupId.isEmpty) throw Exception('Missing groupId');

      final syncClient = ActualSyncClient(
        baseUrl: widget.api.baseUrl,
        token: token,
      );

      _since = _zeroSince;
      await prefs.setString(_sinceKey(widget.fileId), _since);

      var totalEnvelopes = 0;
      var loops = 0;
      while (true) {
        loops++;
        if (loops > 200) {
          throw Exception('Hydrate aborted: too many pages');
        }

        final resp = await syncClient.sync(
          fileId: widget.fileId,
          groupId: groupId,
          since: _since,
        );

        final envs = resp.messages;
        if (envs.isEmpty) break;

        totalEnvelopes += envs.length;

        final maxTs = ActualSyncClient.maxTimestamp(envs);
        if (maxTs.isNotEmpty && maxTs != _since) {
          _since = maxTs;
          await prefs.setString(_sinceKey(widget.fileId), _since);
        }

        final updates = await _decodeEnvelopesInIsolate(envs);
        await _applyUpdatesToSqlite(budget.db, updates);

        if (mounted) {
          // UI breath + show progress
          setState(() {
            _lastSyncError = null;
          });
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      }

      final postCounts = await _dbCounts(budget.db);
      if ((postCounts['accounts'] ?? 0) == 0 &&
          (postCounts['transactions'] ?? 0) == 0) {
        throw Exception(
          'Hydrate completed but DB still empty (accounts/transactions).',
        );
      }

      await prefs.setBool(_hydratedKey(widget.fileId), true);

      final now = DateTime.now();
      _lastSyncAt = now;
      await prefs.setInt(
        _lastSyncAtKey(widget.fileId),
        now.millisecondsSinceEpoch,
      );
      await prefs.remove(_lastSyncErrorKey(widget.fileId));

      // Ensure dashboard gets a refresh after hydration finishes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controllerNotifier.value = controller;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hydrated: $totalEnvelopes updates • accounts=${postCounts['accounts']} • tx=${postCounts['transactions']} • budget=${postCounts['zero_budgets']}',
            ),
          ),
        );
      }
    } catch (e) {
      _lastSyncError = e.toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncErrorKey(widget.fileId), _lastSyncError!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hydrate failed: $_lastSyncError')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  Future<void> _load({bool forceDownload = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (widget.demoMode) {
        _seedDemoData();
        setState(() => _loading = false);
        return;
      }

      // Load sync metadata (cursor + last sync info).
      await _loadSyncMeta();

      final budget = await BudgetLocal.downloadAndOpen(
        api: widget.api,
        fileId: widget.fileId,
        readOnly: false,
        forceDownload: forceDownload,
      );

      _budget = budget;

      // Ensure we have a fully hydrated local DB on first open.
      await _hydrateBudgetIfNeeded();

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
      _selectedAccountId =
          _selectedAccountId ??
          (accounts.isNotEmpty ? accounts.first['id'] as String? : null);
    });

    if (_selectedAccountId != null) {
      await _loadTransactions(_selectedAccountId!);
    }
  }

  String _q(String ident) => '"${ident.replaceAll('"', '""')}"';

  static Object? _decodeValue(String v) {
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

  /// Decode protobuf envelopes off the UI thread (prevents jank / ANR-like behavior).
  Future<List<_SyncUpdate>> _decodeEnvelopesInIsolate(
    List<pb.MessageEnvelope> envs,
  ) async {
    final payload = envs
        .map(
          (e) => _SyncEnvPayload(
            isEncrypted: e.isEncrypted,
            content: Uint8List.fromList(e.content),
          ),
        )
        .toList(growable: false);

    return Isolate.run(() {
      final out = <_SyncUpdate>[];
      for (final env in payload) {
        if (env.isEncrypted) continue;
        final msg = pb.Message.fromBuffer(env.content);
        final dataset = msg.dataset;
        if (dataset == 'prefs') continue;

        out.add(
          _SyncUpdate(
            dataset: dataset,
            rowId: msg.row,
            column: msg.column,
            value: _decodeValue(msg.value),
          ),
        );
      }
      return out;
    });
  }

  Future<void> _applyUpdatesToSqlite(
    dynamic db,
    List<_SyncUpdate> updates,
  ) async {
    // Only supports unencrypted envelopes for MVP.
    await db.transaction((txn) async {
      for (final u in updates) {
        final dataset = u.dataset;
        if (dataset.isEmpty) continue;

        // Best-effort apply. Avoid schema prechecks for now because some
        // sqlite wrappers/transactions behave oddly with PRAGMA + sqlite_master.
        final tableQ = _q(dataset);
        final colQ = _q(u.column);

        try {
          await txn.execute('INSERT OR IGNORE INTO $tableQ (id) VALUES (?)', [
            u.rowId,
          ]);
          await txn.execute('UPDATE $tableQ SET $colQ = ? WHERE id = ?', [
            u.value,
            u.rowId,
          ]);
        } catch (_) {
          // Schema drift happens; don't crash sync.
          continue;
        }
      }
    });
  }

  static String _pinsKey(String fileId) => 'pinnedCats:$fileId';

  Future<List<String>> _getPinnedCategoryIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pinsKey(widget.fileId)) ?? <String>[];
  }

  Future<void> setPinnedCategoryIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final unique = ids.toSet().toList();
    unique.sort();
    await prefs.setStringList(_pinsKey(widget.fileId), unique);
  }

  int _monthStartInt(DateTime now) =>
      (now.year * 10000) + (now.month * 100) + 1;

  int _monthEndInt(DateTime now) {
    final nextMonth = (now.month == 12)
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final lastDay = nextMonth.subtract(const Duration(days: 1));
    return (lastDay.year * 10000) + (lastDay.month * 100) + lastDay.day;
  }

  Future<DashboardData> loadDashboardData() async {
    // Ensure base lists are loaded for the category picker.
    if (_categories.isEmpty && !widget.demoMode) {
      await _reloadFromDb();
    }

    // Demo mode: reuse seeded demo data.
    if (widget.demoMode) {
      final allCats = _categories
          .map(
            (c) => DashboardCategoryChoice(
              id: c['id'] as String? ?? '',
              name: c['name'] as String? ?? '',
            ),
          )
          .where((c) => c.id.isNotEmpty)
          .toList();

      final pinnedIds = (await _getPinnedCategoryIds());
      final effectivePinned = pinnedIds.isNotEmpty
          ? pinnedIds
          : allCats.take(3).map((c) => c.id).toList();

      final pinned = effectivePinned.map((id) {
        final cat = _categories.firstWhere(
          (c) => c['id'] == id,
          orElse: () => {'name': id},
        );
        final name = (cat['name'] as String?) ?? id;
        final spent = _transactions
            .where((t) => t['category'] == id)
            .fold<int>(
              0,
              (sum, t) => sum + ((t['amount'] as num?)?.toInt() ?? 0),
            );
        return DashboardCategory(
          id: id,
          name: name,
          spentThisMonthMilli: spent,
        );
      }).toList();

      final recent = _transactions
          .take(15)
          .map(
            (t) => DashboardTx(
              id: (t['id'] as String?) ?? '',
              date: (t['date'] as num?)?.toInt() ?? 0,
              amountMilli: (t['amount'] as num?)?.toInt() ?? 0,
              description: (t['description'] as String?) ?? '',
              categoryName:
                  _categories.firstWhere(
                        (c) => c['id'] == t['category'],
                        orElse: () => const <String, Object?>{},
                      )['name']
                      as String?,
              accountName: null,
            ),
          )
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
      return DashboardData(
        pinnedCategoryIds: const [],
        pinnedCategories: const [],
        recentTransactions: const [],
        allCategories: const [],
      );
    }

    final allCatsRows = await db.rawQuery(
      'SELECT id, name FROM categories WHERE tombstone = 0 AND is_income = 0 ORDER BY sort_order',
    );
    final allCats = allCatsRows
        .map(
          (r) => DashboardCategoryChoice(
            id: r['id'] as String,
            name: (r['name'] as String?) ?? '',
          ),
        )
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
    final inClause = effectivePins.isEmpty
        ? 'NULL'
        : effectivePins.map((_) => '?').join(',');

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
        .map(
          (r) => DashboardCategory(
            id: r['id'] as String,
            name: (r['name'] as String?) ?? '',
            spentThisMonthMilli: (r['spent'] as num?)?.toInt() ?? 0,
          ),
        )
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
        .map(
          (r) => DashboardTx(
            id: r['id'] as String,
            date: (r['date'] as num?)?.toInt() ?? 0,
            amountMilli: (r['amount'] as num?)?.toInt() ?? 0,
            description: (r['description'] as String?) ?? '',
            accountName: r['account_name'] as String?,
            categoryName: r['category_name'] as String?,
          ),
        )
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
        'balance_current': 245000, // $2450.00
      },
      {
        'id': savingsId,
        'name': 'Savings',
        'type': 'depository',
        'balance_current': 1200000, // $12000.00
      },
      {
        'id': cardId,
        'name': 'Credit Card',
        'type': 'credit',
        'balance_current': -53125, // -$531.25
      },
    ];

    _categoryGroups = [
      {'id': 'cg-income', 'name': 'Income', 'sort_order': 1.0, 'is_income': 1},
      {'id': 'cg-bills', 'name': 'Bills', 'sort_order': 2.0, 'is_income': 0},
      {
        'id': 'cg-frequent',
        'name': 'Frequent',
        'sort_order': 3.0,
        'is_income': 0,
      },
      {'id': 'cg-fun', 'name': 'Fun', 'sort_order': 4.0, 'is_income': 0},
    ];

    _categories = [
      {
        'id': 'c-paycheck',
        'name': 'Paycheck',
        'cat_group': 'cg-income',
        'sort_order': 1.0,
        'is_income': 1,
      },
      {
        'id': 'c-rent',
        'name': 'Rent',
        'cat_group': 'cg-bills',
        'sort_order': 2.0,
        'is_income': 0,
      },
      {
        'id': 'c-electric',
        'name': 'Electric',
        'cat_group': 'cg-bills',
        'sort_order': 3.0,
        'is_income': 0,
      },
      {
        'id': 'c-groceries',
        'name': 'Groceries',
        'cat_group': 'cg-frequent',
        'sort_order': 4.0,
        'is_income': 0,
      },
      {
        'id': 'c-gas',
        'name': 'Gas',
        'cat_group': 'cg-frequent',
        'sort_order': 5.0,
        'is_income': 0,
      },
      {
        'id': 'c-restaurants',
        'name': 'Restaurants',
        'cat_group': 'cg-frequent',
        'sort_order': 6.0,
        'is_income': 0,
      },
      {
        'id': 'c-entertainment',
        'name': 'Entertainment',
        'cat_group': 'cg-fun',
        'sort_order': 7.0,
        'is_income': 0,
      },
    ];

    // date is int YYYYMMDD, amount is integer cents.
    _selectedAccountId = checkingId;
    _transactions = [
      {
        'id': 't1',
        'date': 20260201,
        'amount': 450000,
        'description': 'Paycheck',
        'category': 'c-paycheck',
      },
      {
        'id': 't2',
        'date': 20260202,
        'amount': -150000,
        'description': 'Rent',
        'category': 'c-rent',
      },
      {
        'id': 't3',
        'date': 20260203,
        'amount': -11245,
        'description': 'Groceries',
        'category': 'c-groceries',
      },
      {
        'id': 't4',
        'date': 20260204,
        'amount': -4500,
        'description': 'Gas',
        'category': 'c-gas',
      },
      {
        'id': 't5',
        'date': 20260205,
        'amount': -5899,
        'description': 'Dinner',
        'category': 'c-restaurants',
      },
      {
        'id': 't6',
        'date': 20260206,
        'amount': -1490,
        'description': 'Movie rental',
        'category': 'c-entertainment',
      },
      {
        'id': 't7',
        'date': 20260207,
        'amount': -8910,
        'description': 'Electric bill',
        'category': 'c-electric',
      },
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
    final cols = <String>{for (final r in rows) (r['name'] as String?) ?? ''}
      ..remove('');

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

    final hasPayeesTable = await _tableExists(db, 'payees');

    // Some schemas store the payee id in `description` (!). If we see payees but
    // no explicit payee column, we can best-effort join payees on description.
    final joinPayeeOnDescription =
        payeeCol == null && hasPayeesTable && txCols.contains('description');

    final hasPayees =
        (payeeCol != null && hasPayeesTable) || joinPayeeOnDescription;

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
      if (hasPayees)
        joinPayeeOnDescription
            ? 'LEFT JOIN payees p ON p.id = t.description'
            : 'LEFT JOIN payees p ON p.id = t.$payeeCol',
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

  final _moneyFmt = NumberFormat('#,##0.00');

  String _fmtMoney(Object? v) {
    if (v == null) return '';
    // Actual stores amounts as integer cents.
    final cents = (v as num).toInt();
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final value = abs / 100.0;
    return '$sign\$${_moneyFmt.format(value)}';
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
            onPressed: (_loading || _syncing)
                ? null
                : () async {
                    await syncNow();
                  },
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Now',
          ),
          IconButton(
            onPressed: (_loading || _syncing)
                ? null
                : () => _load(forceDownload: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-download',
          ),
          AppMenuButton(api: widget.api),
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
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  _buildSyncBanner(),
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

  Widget _buildSyncBanner() {
    if (widget.demoMode) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Demo mode (no server sync)',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final last = _lastSyncAt;
    final err = _lastSyncError;

    if (_syncing) {
      return const Padding(
        padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 4),
        child: LinearProgressIndicator(),
      );
    }

    if (err != null && err.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Last sync failed: $err',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
    }

    if (last != null) {
      final ts = DateFormat('yyyy-MM-dd HH:mm').format(last);
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Last sync: $ts',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAccounts() {
    return ListView.separated(
      itemCount: _accounts.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final a = _accounts[i];
        final id = a['id'] as String?;
        final name = (a['name'] as String?) ?? '(unnamed)';
        final type = (a['type'] as String?) ?? '';
        final offbudget = (a['offbudget'] as num?)?.toInt() ?? 0;
        final closed = (a['closed'] as num?)?.toInt() ?? 0;

        final balCurrent = _fmtMoney(a['balance_current']);
        final balAvailRaw = a['balance_available'];
        final balAvail = balAvailRaw == null ? null : _fmtMoney(balAvailRaw);

        final subtitleParts = <String>[type];
        if (offbudget != 0) subtitleParts.add('Off budget');
        if (closed != 0) subtitleParts.add('Closed');

        return ListTile(
          title: Text(name),
          subtitle: Text(
            subtitleParts.where((s) => s.trim().isNotEmpty).join(' • '),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(balCurrent),
              if (balAvail != null && balAvail != balCurrent)
                Text(
                  'Avail $balAvail',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
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
              final txId = (t['id'] as String?) ?? '';
              final desc = (t['description'] as String?) ?? '';

              bool isUuidLike(String s) {
                final v = s.trim();
                final r = RegExp(
                  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                );
                return r.hasMatch(v);
              }

              final dateRaw = t['date'];
              final date = _fmtDate(dateRaw);
              final rawAmt = t['amount'];
              final amt = _fmtMoney(rawAmt);
              final notes = (t['notes'] as String?) ?? '';

              final categoryName =
                  (t['category_name'] as String?) ??
                  _categories.firstWhere(
                        (c) => c['id'] == t['category'],
                        orElse: () => const <String, Object?>{},
                      )['name']
                      as String?;

              final accountName = (t['account_name'] as String?);
              final payeeName = (t['payee_name'] as String?);

              final titleText = (payeeName != null && payeeName.isNotEmpty)
                  ? payeeName
                  : (isUuidLike(desc) ? '' : desc);

              final cleared = (t['cleared'] as num?)?.toInt();
              final reconciled = (t['reconciled'] as num?)?.toInt();

              final flags = <String>[];
              if (reconciled != null && reconciled != 0) flags.add('R');
              if (cleared != null && cleared != 0) flags.add('C');

              final subtitleParts = <String>[date];
              if (payeeName != null && payeeName.isNotEmpty) {
                subtitleParts.add(payeeName);
              }
              if (categoryName != null && categoryName.isNotEmpty) {
                subtitleParts.add(categoryName);
              }
              if (flags.isNotEmpty) subtitleParts.add(flags.join(','));

              final notesPreview = notes.trim();

              return ListTile(
                title: Text(titleText.isEmpty ? '(no description)' : titleText),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtitleParts.join(' • ')),
                    if (notesPreview.isNotEmpty)
                      Text(
                        notesPreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(amt),
                    Text(
                      'raw: ${rawAmt ?? ''}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                onTap: txId.isEmpty
                    ? null
                    : () => _showTransactionDetail(
                        tx: t,
                        dateLabel: date,
                        amountLabel: amt,
                        accountName: accountName,
                        categoryName: categoryName,
                        payeeName: payeeName,
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showTransactionDetail({
    required Map<String, Object?> tx,
    required String dateLabel,
    required String amountLabel,
    required String? accountName,
    required String? categoryName,
    required String? payeeName,
  }) {
    final desc = (tx['description'] as String?) ?? '';
    final notes = (tx['notes'] as String?) ?? '';
    final flags = <String>[];
    final cleared = (tx['cleared'] as num?)?.toInt();
    final reconciled = (tx['reconciled'] as num?)?.toInt();
    if (reconciled != null && reconciled != 0) flags.add('Reconciled');
    if (cleared != null && cleared != 0) flags.add('Cleared');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SelectionArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            desc.isEmpty ? '(no description)' : desc,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              amountLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'raw: ${tx['amount'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _detailRow('Date', dateLabel),
                    if (payeeName != null && payeeName.isNotEmpty)
                      _detailRow('Payee', payeeName),
                    if (categoryName != null && categoryName.isNotEmpty)
                      _detailRow('Category', categoryName),
                    if (accountName != null && accountName.isNotEmpty)
                      _detailRow('Account', accountName),
                    if (flags.isNotEmpty)
                      _detailRow('Status', flags.join(' • ')),
                    if (notes.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Notes', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(notes),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Raw map (copyable)',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      tx.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(k, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  Future<int> _spentThisMonthForCategory(String categoryId) async {
    if (widget.demoMode) {
      return _transactions
          .where((t) => t['category'] == categoryId)
          .fold<int>(
            0,
            (sum, t) => sum + ((t['amount'] as num?)?.toInt() ?? 0),
          );
    }

    final db = _budget?.db;
    if (db == null) return 0;

    final now = DateTime.now();
    final start = _monthStartInt(now);
    final end = _monthEndInt(now);

    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as spent '
      'FROM transactions '
      'WHERE tombstone = 0 AND category = ? AND date BETWEEN ? AND ?',
      [categoryId, start, end],
    );

    return (rows.first['spent'] as num?)?.toInt() ?? 0;
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
          child: Text(
            'Budget (this month)',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        for (final g in _categoryGroups) ...[
          Builder(
            builder: (context) {
              final gid = (g['id'] as String?) ?? '';
              final cats = byGroup[gid] ?? const <Map<String, Object?>>[];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    title: Text(
                      (g['name'] as String?) ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${cats.length} categories'),
                  ),
                  for (final c in cats)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FutureBuilder<int>(
                        future: _spentThisMonthForCategory(
                          (c['id'] as String?) ?? '',
                        ),
                        builder: (context, snap) {
                          final spent = snap.data ?? 0;
                          return ListTile(
                            dense: true,
                            title: Text((c['name'] as String?) ?? ''),
                            subtitle: const Text('Spent (this month)'),
                            trailing: Text(_fmtMoney(spent)),
                          );
                        },
                      ),
                    ),
                  const Divider(height: 1),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
