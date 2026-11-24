import 'dart:convert';
import 'package:http/http.dart' as http;

/// ApiClient communicates with the local tandemd daemon over loopback API (127.0.0.1:8385).
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

  Future<Map<String, dynamic>> getStatus() async {
    final resp = await _client.get(Uri.parse('$baseUrl/status'), headers: _headers);
    if (resp.statusCode == 200) {
      return json.decode(resp.body);
    }
    throw Exception('Failed to get status: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> getHealth() async {
    final resp = await _client.get(Uri.parse('$baseUrl/health'), headers: _headers);
    if (resp.statusCode == 200) {
      return json.decode(resp.body);
    }
    throw Exception('Failed to get health: ${resp.statusCode}');
  }

  Future<List<dynamic>> getDevices() async {
    final resp = await _client.get(Uri.parse('$baseUrl/devices'), headers: _headers);
    if (resp.statusCode == 200) {
      return json.decode(resp.body);
    }
    throw Exception('Failed to get devices: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> pairDevice({
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
        if (addressHint != null) 'addressHint': addressHint,
      }),
    );
    if (resp.statusCode == 201) {
      return json.decode(resp.body);
    }
    throw Exception('Failed to pair device: ${resp.statusCode}');
  }

  Future<void> unpairDevice(String deviceId) async {
    final resp = await _client.delete(
      Uri.parse('$baseUrl/devices/$deviceId'),
      headers: _headers,
    );
    if (resp.statusCode != 204) {
      throw Exception('Failed to unpair device: ${resp.statusCode}');
    }
  }

  Future<List<dynamic>> getFolders() async {
    final resp = await _client.get(Uri.parse('$baseUrl/folders'), headers: _headers);
    if (resp.statusCode == 200) {
      return json.decode(resp.body);
    }
    throw Exception('Failed to get folders: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> addFolder({
    required String path,
    String? label,
    String type = 'sendreceive',
    List<String> sharedDevices = const [],
  }) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/folders'),
      headers: _headers,
      body: json.encode({
        'path': path,
        if (label != null) 'label': label,
        'type': type,
        'sharedDevices': sharedDevices,
      }),
    );
    if (resp.statusCode == 201) {
      return json.decode(resp.body);
    }
    throw Exception('Failed to add folder: ${resp.statusCode}');
  }

  Future<void> removeFolder(String folderId) async {
    final resp = await _client.delete(
      Uri.parse('$baseUrl/folders/$folderId'),
      headers: _headers,
    );
    if (resp.statusCode != 204) {
      throw Exception('Failed to remove folder: ${resp.statusCode}');
    }
  }

  Future<Map<String, dynamic>> initiateSend({
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
      return json.decode(resp.body);
    }
    throw Exception('Failed to initiate send: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> getPairingCode() async {
    final resp = await _client.get(Uri.parse('$baseUrl/pairing/code'), headers: _headers);
    if (resp.statusCode == 200) {
      return json.decode(resp.body);
    }
    throw Exception('Failed to get pairing code: ${resp.statusCode}');
  }

  Future<bool> confirmPairing({
    required String targetDeviceId,
    required String confirmedCode,
  }) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/pairing/confirm'),
      headers: _headers,
      body: json.encode({
        'targetDeviceId': targetDeviceId,
        'confirmedCode': confirmedCode,
      }),
    );
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      return data['success'] == true;
    }
    return false;
  }
}
