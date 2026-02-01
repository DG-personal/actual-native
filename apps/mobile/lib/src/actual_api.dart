import 'dart:convert';

import 'package:http/http.dart' as http;

class ActualApi {
  ActualApi({required this.baseUrl});

  final String baseUrl;
  String? token;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> needsBootstrap() async {
    final res = await http.get(_u('/account/needs-bootstrap'));
    return _decodeJson(res);
  }

  Future<Map<String, dynamic>> bootstrap({required String password}) async {
    final res = await http.post(
      _u('/account/bootstrap'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    );
    return _decodeJson(res);
  }

  Future<void> login({required String password}) async {
    final res = await http.post(
      _u('/account/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    );
    final json = _decodeJson(res);
    final data = json['data'] as Map<String, dynamic>?;
    final t = data?['token'] as String?;
    if (t == null || t.isEmpty) {
      throw Exception('No token returned');
    }
    token = t;
  }

  Future<List<dynamic>> listUserFiles() async {
    if (token == null) throw Exception('Not logged in');
    final res = await http.get(
      _u('/sync/list-user-files'),
      headers: {'x-actual-token': token!},
    );
    final json = _decodeJson(res);
    final data = json['data'] as List<dynamic>?;
    return data ?? [];
  }

  Future<Map<String, dynamic>> getUserFileInfo({required String fileId}) async {
    if (token == null) throw Exception('Not logged in');
    final res = await http.get(
      _u('/sync/get-user-file-info'),
      headers: {
        'x-actual-token': token!,
        'x-actual-file-id': fileId,
      },
    );
    return _decodeJson(res);
  }

  Future<int> downloadUserFileSize({required String fileId}) async {
    if (token == null) throw Exception('Not logged in');
    final res = await http.get(
      _u('/sync/download-user-file'),
      headers: {
        'x-actual-token': token!,
        'x-actual-file-id': fileId,
      },
    );
    if (res.statusCode >= 400) {
      throw Exception('Download failed (${res.statusCode})');
    }
    return res.bodyBytes.length;
  }

  Map<String, dynamic> _decodeJson(http.Response res) {
    final body = res.body;
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(json['reason'] ?? 'HTTP ${res.statusCode}');
    }
    if (json['status'] != 'ok') {
      throw Exception(json['reason'] ?? 'Request failed');
    }
    return json;
  }
}
