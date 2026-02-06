import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'actual_api.dart';

class LocalBudget {
  LocalBudget({required this.fileId, required this.dir, required this.db});

  final String fileId;
  final Directory dir;
  final Database db;

  Future<void> close() => db.close();
}

class BudgetLocal {
  static Future<LocalBudget> downloadAndOpen({
    required ActualApi api,
    required String fileId,
    bool readOnly = true,
    bool forceDownload = false,
  }) async {
    final supportDir = await getApplicationSupportDirectory();
    final budgetDir = Directory(p.join(supportDir.path, 'budgets', fileId));
    if (!await budgetDir.exists()) {
      await budgetDir.create(recursive: true);
    }

    final existingDb = File(p.join(budgetDir.path, 'db.sqlite'));
    if (!forceDownload && await existingDb.exists()) {
      final db = await openDatabase(existingDb.path, readOnly: readOnly);
      return LocalBudget(fileId: fileId, dir: budgetDir, db: db);
    }

    final zipBytes = await api.downloadUserFileBytes(fileId: fileId);
    final dbFile = await _extractDbSqlite(
      zipBytes: zipBytes,
      outDir: budgetDir,
    );

    final db = await openDatabase(dbFile.path, readOnly: readOnly);
    return LocalBudget(fileId: fileId, dir: budgetDir, db: db);
  }

  static Future<File> _extractDbSqlite({
    required Uint8List zipBytes,
    required Directory outDir,
  }) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    ArchiveFile? dbEntry;

    for (final e in archive) {
      if (!e.isFile) continue;
      final name = e.name;
      if (name.endsWith('db.sqlite') || name.endsWith('/db.sqlite')) {
        dbEntry = e;
        break;
      }
    }

    if (dbEntry == null) {
      throw Exception('db.sqlite not found in zip');
    }

    final outFile = File(p.join(outDir.path, 'db.sqlite'));
    final data = Uint8List.fromList(dbEntry.content as List<int>);
    await outFile.writeAsBytes(data, flush: true);
    return outFile;
  }
}
