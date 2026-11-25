import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Typed REST & SSE client communicating strictly with local tandemd over loopback.
class ApiClient {
  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  ApiClient({
    this.baseUrl = 'http://127.0.0.1:8385/api/v1',
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  Future<DaemonStatus> getStatus() async {
    final resp = await _client.get(Uri.parse('$baseUrl/status'), headers: _headers);
    if (resp.statusCode == 200) {
      return DaemonStatus.fromJson(json.decode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to get status (${resp.statusCode})');
  }

  Future<SystemHealth> getHealth() async {
    final resp = await _client.get(Uri.parse('$baseUrl/health'), headers: _headers);
    if (resp.statusCode == 200) {
      return SystemHealth.fromJson(json.decode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to get health (${resp.statusCode})');
  }

  Future<List<TandemDevice>> getDevices() async {
    final resp = await _client.get(Uri.parse('$baseUrl/devices'), headers: _headers);
    if (resp.statusCode == 200) {
      final list = json.decode(resp.body) as List<dynamic>;
      return list.map((e) => TandemDevice.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to get devices (${resp.statusCode})');
  }

  Future<TandemDevice> pairDevice({
    required String deviceId,
    required String name,
    String? addressHint,
  }) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/devices'),
      headers: _headers,
      body: json.encode({
        'deviceId': deviceId,
        'name': name,
        if (addressHint != null && addressHint.isNotEmpty) 'addressHint': addressHint,
      }),
    );
    if (resp.statusCode == 201) {
      return TandemDevice.fromJson(json.decode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to pair device (${resp.statusCode}): ${resp.body}');
  }

  Future<void> unpairDevice(String deviceId) async {
    final resp = await _client.delete(
      Uri.parse('$baseUrl/devices/$deviceId'),
      headers: _headers,
    );
    if (resp.statusCode != 204) {
      throw Exception('Failed to unpair device (${resp.statusCode})');
    }
  }

  Future<List<TandemFolder>> getFolders() async {
    final resp = await _client.get(Uri.parse('$baseUrl/folders'), headers: _headers);
    if (resp.statusCode == 200) {
      final list = json.decode(resp.body) as List<dynamic>;
      return list.map((e) => TandemFolder.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to get folders (${resp.statusCode})');
  }

  Future<TandemFolder> addFolder({
    String? id,
    required String path,
    String? label,
    String type = 'sendreceive',
    List<String> sharedDevices = const [],
  }) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/folders'),
      headers: _headers,
      body: json.encode({
        if (id != null && id.isNotEmpty) 'id': id,
        'path': path,
        if (label != null && label.isNotEmpty) 'label': label,
        'type': type,
        'sharedDevices': sharedDevices,
      }),
    );
    if (resp.statusCode == 201) {
      return TandemFolder.fromJson(json.decode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to add folder (${resp.statusCode}): ${resp.body}');
  }

  Future<TandemFolder> updateFolder(
    String folderId, {
    bool? paused,
    String? type,
    List<String>? sharedDevices,
  }) async {
    final resp = await _client.patch(
      Uri.parse('$baseUrl/folders/$folderId'),
      headers: _headers,
      body: json.encode({
        if (paused != null) 'paused': paused,
        if (type != null) 'type': type,
        if (sharedDevices != null) 'sharedDevices': sharedDevices,
      }),
    );
    if (resp.statusCode == 200) {
      return TandemFolder.fromJson(json.decode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to update folder (${resp.statusCode})');
  }

  Future<void> removeFolder(String folderId) async {
    final resp = await _client.delete(
      Uri.parse('$baseUrl/folders/$folderId'),
      headers: _headers,
    );
    if (resp.statusCode != 204) {
      throw Exception('Failed to remove folder (${resp.statusCode})');
    }
  }

  Future<List<FolderErrorItem>> getFolderErrors(String folderId) async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/folders/$folderId/errors'),
      headers: _headers,
    );
    if (resp.statusCode == 200) {
      final list = json.decode(resp.body) as List<dynamic>;
      return list.map((e) => FolderErrorItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load folder errors (${resp.statusCode})');
  }

  Future<List<TrashItem>> getFolderTrash(String folderId) async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/folders/$folderId/trash'),
      headers: _headers,
    );
    if (resp.statusCode == 200) {
      final list = json.decode(resp.body) as List<dynamic>;
      return list.map((e) => TrashItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load folder trash (${resp.statusCode})');
  }

  Future<void> restoreTrashItem(String folderId, String trashId) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/folders/$folderId/trash/restore'),
      headers: _headers,
      body: json.encode({'trashId': trashId}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to restore file (${resp.statusCode}): ${resp.body}');
    }
  }

  Future<List<SendSession>> listSendSessions() async {
    final resp = await _client.get(Uri.parse('$baseUrl/send'), headers: _headers);
    if (resp.statusCode == 200) {
      final list = json.decode(resp.body) as List<dynamic>;
      return list.map((e) => SendSession.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to list send sessions (${resp.statusCode})');
  }

  Future<SendSession> initiateSend({
    required String targetDeviceId,
    required List<String> filePaths,
  }) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/send'),
      headers: _headers,
      body: json.encode({
        'targetDeviceId': targetDeviceId,
        'filePaths': filePaths,
      }),
    );
    if (resp.statusCode == 202) {
      return SendSession.fromJson(json.decode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to initiate send (${resp.statusCode}): ${resp.body}');
  }

  Future<SendSession> getSendSession(String sessionId) async {
    final resp = await _client.get(Uri.parse('$baseUrl/send/$sessionId'), headers: _headers);
    if (resp.statusCode == 200) {
      return SendSession.fromJson(json.decode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to get send session (${resp.statusCode})');
  }

  Future<PairingPayload> getPairingCode() async {
    final resp = await _client.get(Uri.parse('$baseUrl/pairing/code'), headers: _headers);
    if (resp.statusCode == 200) {
      return PairingPayload.fromJson(json.decode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to get pairing code (${resp.statusCode})');
  }

  Future<bool> confirmPairing({
    required String targetDeviceId,
    required String confirmedCode,
    String? name,
    String? addressHint,
  }) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/pairing/confirm'),
      headers: _headers,
      body: json.encode({
        'targetDeviceId': targetDeviceId,
        'confirmedCode': confirmedCode,
        if (name != null) 'name': name,
        if (addressHint != null) 'addressHint': addressHint,
      }),
    );
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body) as Map<String, dynamic>;
      return data['success'] == true;
    }
    return false;
  }

  Stream<DaemonEvent> subscribeEvents() async* {
    final req = http.Request('GET', Uri.parse('$baseUrl/events'));
    req.headers.addAll({
      'Authorization': 'Bearer $apiKey',
      'Accept': 'text/event-stream',
    });
    final streamed = await _client.send(req);
    if (streamed.statusCode != 200) {
      throw Exception('SSE stream error (${streamed.statusCode})');
    }
    await for (final line in streamed.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      final payload = line.substring(6).trim();
      if (payload.isEmpty) continue;
      try {
        final decoded = json.decode(payload) as Map<String, dynamic>;
        yield DaemonEvent(
          event: decoded['event']?.toString() ?? decoded['type']?.toString() ?? 'unknown',
          raw: decoded,
        );
      } catch (_) {}
    }
  }
}
