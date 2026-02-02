import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'pb/sync.pb.dart' as pb;

class ActualSyncClient {
  ActualSyncClient({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<pb.SyncResponse> sync({
    required String fileId,
    required String groupId,
    required String since,
    List<pb.MessageEnvelope> outgoing = const [],
    String keyId = '',
  }) async {
    final req = pb.SyncRequest()
      ..fileId = fileId
      ..groupId = groupId
      ..since = since
      ..keyId = keyId;

    req.messages.addAll(outgoing);

    final body = Uint8List.fromList(req.writeToBuffer());

    final res = await http.post(
      _u('/sync/sync'),
      headers: {
        'content-type': 'application/actual-sync',
        'x-actual-token': token,
      },
      body: body,
    );

    if (res.statusCode != 200) {
      throw Exception('Sync failed: HTTP ${res.statusCode} ${res.body}');
    }

    return pb.SyncResponse.fromBuffer(res.bodyBytes);
  }

  static String maxTimestamp(List<pb.MessageEnvelope> envs) {
    String maxTs = '';
    for (final e in envs) {
      if (e.timestamp.compareTo(maxTs) > 0) maxTs = e.timestamp;
    }
    return maxTs;
  }
}
