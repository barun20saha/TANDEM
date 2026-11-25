import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/daemon_launcher.dart';

enum ViewLoadState {
  loading,
  ready,
  error,
}

/// Single source of truth for UI state backed strictly by tandemd API + SSE events.
class TandemController extends ChangeNotifier {
  ApiClient? _client;
  final DaemonLauncher _launcher;

  ViewLoadState connectionState = ViewLoadState.loading;
  String? connectionError;

  DaemonStatus? status;
  SystemHealth? health;
  List<TandemDevice> devices = const [];
  List<TandemFolder> folders = const [];
  List<SendSession> sendSessions = const [];
  PairingPayload? pairingPayload;
  final List<DaemonEvent> recentEvents = [];

  StreamSubscription<DaemonEvent>? _sseSub;
  Timer? _pollTimer;

  TandemController({ApiClient? client, DaemonLauncher? launcher})
      : _client = client,
        _launcher = launcher ?? DaemonLauncher();

  ApiClient? get client => _client;

  Future<void> initialize() async {
    connectionState = ViewLoadState.loading;
    connectionError = null;
    notifyListeners();

    try {
      if (_client == null) {
        final res = await _launcher.connectOrStart();
        _client = res.client;
      }
      await refreshAll();
      connectionState = ViewLoadState.ready;
      _startListeners();
    } catch (e) {
      connectionState = ViewLoadState.error;
      connectionError = e.toString();
    }
    notifyListeners();
  }

  Future<void> refreshAll() async {
    final c = _client;
    if (c == null) return;

    final results = await Future.wait([
      c.getStatus(),
      c.getHealth(),
      c.getDevices(),
      c.getFolders(),
      c.listSendSessions(),
    ]);
    status = results[0] as DaemonStatus;
    health = results[1] as SystemHealth;
    devices = results[2] as List<TandemDevice>;
    folders = results[3] as List<TandemFolder>;
    sendSessions = results[4] as List<SendSession>;
    connectionState = ViewLoadState.ready;
    connectionError = null;
    notifyListeners();
  }

  Future<void> loadPairingCode() async {
    final c = _client;
    if (c == null) return;
    pairingPayload = await c.getPairingCode();
    notifyListeners();
  }

  Future<bool> pairByCode({
    required String targetDeviceId,
    required String confirmedCode,
    String? name,
    String? addressHint,
  }) async {
    final c = _client;
    if (c == null) return false;
    final ok = await c.confirmPairing(
      targetDeviceId: targetDeviceId,
      confirmedCode: confirmedCode,
      name: name,
      addressHint: addressHint,
    );
    if (ok) await refreshAll();
    return ok;
  }

  Future<void> pairDevice({
    required String deviceId,
    required String name,
    String? addressHint,
  }) async {
    final c = _client;
    if (c == null) return;
    await c.pairDevice(deviceId: deviceId, name: name, addressHint: addressHint);
    await refreshAll();
  }

  Future<void> unpairDevice(String deviceId) async {
    final c = _client;
    if (c == null) return;
    await c.unpairDevice(deviceId);
    await refreshAll();
  }

  Future<void> addFolder({
    required String path,
    String? label,
    String type = 'sendreceive',
    List<String> sharedDevices = const [],
  }) async {
    final c = _client;
    if (c == null) return;
    await c.addFolder(path: path, label: label, type: type, sharedDevices: sharedDevices);
    await refreshAll();
  }

  Future<void> updateFolder(
    String folderId, {
    bool? paused,
    String? type,
    List<String>? sharedDevices,
  }) async {
    final c = _client;
    if (c == null) return;
    await c.updateFolder(folderId, paused: paused, type: type, sharedDevices: sharedDevices);
    await refreshAll();
  }

  Future<void> removeFolder(String folderId) async {
    final c = _client;
    if (c == null) return;
    await c.removeFolder(folderId);
    await refreshAll();
  }

  Future<SendSession?> sendFiles({
    required String targetDeviceId,
    required List<String> filePaths,
  }) async {
    final c = _client;
    if (c == null) return null;
    final sess = await c.initiateSend(targetDeviceId: targetDeviceId, filePaths: filePaths);
    await refreshAll();
    return sess;
  }

  void _startListeners() {
    _sseSub?.cancel();
    _pollTimer?.cancel();
    final c = _client;
    if (c == null) return;

    _sseSub = c.subscribeEvents().listen(
      (ev) {
        recentEvents.insert(0, ev);
        if (recentEvents.length > 50) recentEvents.removeLast();
        refreshAll().catchError((_) {});
      },
      onError: (_) {},
    );

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      refreshAll().catchError((_) {});
    });
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
