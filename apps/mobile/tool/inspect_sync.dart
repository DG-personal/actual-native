// ignore_for_file: avoid_relative_lib_imports, avoid_print

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../lib/src/sync/actual_sync_client.dart';
import '../lib/src/sync/pb/sync.pb.dart' as pb;

Future<void> main(List<String> args) async {
  final baseUrl = args.isNotEmpty ? args[0] : 'http://127.0.0.1:5006';
  final password = args.length > 1 ? args[1] : '';
  if (password.isEmpty) {
    throw Exception('Usage: dart run tool/inspect_sync.dart <baseUrl> <password>');
  }

  // Login
  final loginRes = await http.post(
    Uri.parse('$baseUrl/account/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'password': password}),
  );
  final loginJson = jsonDecode(loginRes.body) as Map<String, dynamic>;
  final token = (loginJson['data'] as Map<String, dynamic>)['token'] as String;

  // list files
  final filesRes = await http.get(
    Uri.parse('$baseUrl/sync/list-user-files'),
    headers: {'x-actual-token': token},
  );
  final filesJson = jsonDecode(filesRes.body) as Map<String, dynamic>;
  final files = (filesJson['data'] as List).cast<Map<String, dynamic>>();
  if (files.isEmpty) {
    print('no files');
    return;
  }
  final fileId = files.first['fileId'] as String;

  // get file info
  final infoRes = await http.get(
    Uri.parse('$baseUrl/sync/get-user-file-info'),
    headers: {'x-actual-token': token, 'x-actual-file-id': fileId},
  );
  final infoJson = jsonDecode(infoRes.body) as Map<String, dynamic>;
  final groupId = (infoJson['data'] as Map<String, dynamic>)['groupId'] as String;

  print('fileId=$fileId groupId=$groupId');

  final client = ActualSyncClient(baseUrl: baseUrl, token: token);
  final resp = await client.sync(
    fileId: fileId,
    groupId: groupId,
    since: '1970-01-01T00:00:00.000Z-0000-0000000000000000',
  );

  print('envelopes=${resp.messages.length}');

  final datasetCounts = <String, int>{};
  var encrypted = 0;
  for (final env in resp.messages) {
    if (env.isEncrypted) {
      encrypted++;
      continue;
    }
    final m = pb.Message.fromBuffer(env.content);
    datasetCounts[m.dataset] = (datasetCounts[m.dataset] ?? 0) + 1;
  }
  print('encrypted=$encrypted');
  final keys = datasetCounts.keys.toList()..sort();
  for (final k in keys) {
    print('dataset $k = ${datasetCounts[k]}');
  }

  void dumpSome(String dataset, int max) {
    var n = 0;
    for (final env in resp.messages) {
      if (env.isEncrypted) continue;
      final m = pb.Message.fromBuffer(env.content);
      if (m.dataset != dataset) continue;
      print('$dataset: row=${m.row} col=${m.column} val=${m.value}');
      n++;
      if (n >= max) break;
    }
  }

  dumpSome('accounts', 10);
  dumpSome('transactions', 10);
}
