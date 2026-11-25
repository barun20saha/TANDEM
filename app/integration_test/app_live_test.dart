import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tandem/l10n/strings.dart';
import 'package:tandem/main.dart';
import 'package:tandem/screens/first_run_screen.dart';
import 'package:tandem/services/api_client.dart';
import 'package:tandem/state/tandem_controller.dart';

Future<int> _freeTcpPort() async {
  final srv = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final p = srv.port;
  await srv.close();
  return p;
}

Future<int> _freeUdpPort() async {
  final sock = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final p = sock.port;
  sock.close();
  return p;
}

String _findCoreDir() {
  final candidates = <Directory>[Directory.current];
  try {
    candidates.add(File(Platform.resolvedExecutable).parent);
  } catch (_) {}
  for (final start in candidates) {
    var cur = start.absolute;
    for (var i = 0; i < 8; i++) {
      final probe = Directory('${cur.path}/core');
      if (File('${probe.path}/cmd/tandemd/main.go').existsSync()) {
        return probe.path;
      }
      if (cur.parent.path == cur.path) break;
      cur = cur.parent;
    }
  }
  throw StateError('Unable to locate core/ directory from ${Directory.current.path}');
}

/// Live desktop integration test (Gate A5) intended for `flutter test -d linux`
/// under `xvfb-run` with `go` and `syncthing` on PATH.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Live TandemApp pairs two real tandemd instances and syncs real files',
      (WidgetTester tester) async {
    await TandemStrings.load();
    final tmpRoot = Directory.systemTemp.createTempSync('tandem-it-');
    addTearDown(() => tmpRoot.deleteSync(recursive: true));

    final coreDir = _findCoreDir();
    final binPath = '${tmpRoot.path}/tandemd';
    final buildRes = Process.runSync(
      'go',
      ['build', '-o', binPath, './cmd/tandemd'],
      workingDirectory: coreDir,
      environment: {
        ...Platform.environment,
        'CGO_ENABLED': '0',
      },
    );
    expect(buildRes.exitCode, 0, reason: 'go build failed: ${buildRes.stderr}');

    final apiPortA = await _freeTcpPort();
    final syncPortA = await _freeTcpPort();
    final guiPortA = await _freeTcpPort();
    final apiPortB = await _freeTcpPort();
    final syncPortB = await _freeTcpPort();
    final guiPortB = await _freeTcpPort();
    final discPort = await _freeUdpPort();

    final cfgA = Directory('${tmpRoot.path}/cfgA')..createSync();
    final cfgB = Directory('${tmpRoot.path}/cfgB')..createSync();
    final syncA = Directory('${tmpRoot.path}/syncA')..createSync();
    final syncB = Directory('${tmpRoot.path}/syncB')..createSync();
    File('${syncA.path}/hello.txt').writeAsStringSync('live-integration-sync');

    final logsA = StringBuffer();
    final logsB = StringBuffer();

    final procA = await Process.start(binPath, [
      '-config', cfgA.path,
      '-bind', '127.0.0.1:$apiPortA',
      '-sync-port', '$syncPortA',
      '-discovery-port', '$discPort',
      '-engine-gui', '127.0.0.1:$guiPortA',
      '-device-name', 'LiveNodeA',
      '-global-discovery=false',
      '-relays=false',
      '-nat=false',
    ]);
    procA.stdout.transform(utf8.decoder).listen(logsA.write);
    procA.stderr.transform(utf8.decoder).listen(logsA.write);

    final procB = await Process.start(binPath, [
      '-config', cfgB.path,
      '-bind', '127.0.0.1:$apiPortB',
      '-sync-port', '$syncPortB',
      '-discovery-port', '$discPort',
      '-engine-gui', '127.0.0.1:$guiPortB',
      '-device-name', 'LiveNodeB',
      '-global-discovery=false',
      '-relays=false',
      '-nat=false',
    ]);
    procB.stdout.transform(utf8.decoder).listen(logsB.write);
    procB.stderr.transform(utf8.decoder).listen(logsB.write);

    addTearDown(() async {
      procA.kill(ProcessSignal.sigterm);
      procB.kill(ProcessSignal.sigterm);
      await Future.wait([procA.exitCode, procB.exitCode])
          .timeout(const Duration(seconds: 5), onTimeout: () {
        procA.kill(ProcessSignal.sigkill);
        procB.kill(ProcessSignal.sigkill);
        return [0, 0];
      });
    });

    Future<ApiClient> waitReady(String cfgDir, int port, StringBuffer logs) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        final keyFile = File('$cfgDir/api.key');
        if (keyFile.existsSync()) {
          final key = keyFile.readAsStringSync().trim();
          if (key.isNotEmpty) {
            final client = ApiClient(baseUrl: 'http://127.0.0.1:$port/api/v1', apiKey: key);
            try {
              final h = await client.getHealth();
              if (h.engineReady) return client;
            } catch (_) {}
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      throw StateError('Daemon on 127.0.0.1:$port failed to become healthy.\nLogs:\n$logs');
    }

    final clientA = await waitReady(cfgA.path, apiPortA, logsA);
    final clientB = await waitReady(cfgB.path, apiPortB, logsB);

    final ctrlA = TandemController(client: clientA);
    addTearDown(ctrlA.dispose);
    await ctrlA.refreshAll();

    await tester.pumpWidget(TandemApp(controller: ctrlA, themeMode: ThemeMode.light));
    await tester.pumpAndSettle();
    expect(find.byType(FirstRunScreen), findsOneWidget);

    final statusA = await clientA.getStatus();
    final statusB = await clientB.getStatus();
    await clientA.pairDevice(
      deviceId: statusB.myDeviceId,
      name: 'LiveNodeB',
      addressHint: 'tcp://127.0.0.1:$syncPortB',
    );
    await clientB.pairDevice(
      deviceId: statusA.myDeviceId,
      name: 'LiveNodeA',
      addressHint: 'tcp://127.0.0.1:$syncPortA',
    );
    await clientA.addFolder(
      id: 'live-shared',
      path: syncA.path,
      label: 'LiveSync',
      sharedDevices: [statusB.myDeviceId],
    );
    final foldersA = await clientA.getFolders();
    await clientB.addFolder(
      id: 'live-shared',
      path: syncB.path,
      label: 'LiveSync',
      sharedDevices: [statusA.myDeviceId],
    );

    final syncedFile = File('${syncB.path}/hello.txt');
    final syncDeadline = DateTime.now().add(const Duration(seconds: 45));
    while (DateTime.now().isBefore(syncDeadline)) {
      if (syncedFile.existsSync() &&
          syncedFile.readAsStringSync() == 'live-integration-sync') {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    expect(syncedFile.existsSync(), isTrue);
    expect(syncedFile.readAsStringSync(), 'live-integration-sync');

    expect(foldersA, isNotEmpty);
    await ctrlA.refreshAll();
    await tester.pumpAndSettle();
    expect(find.text('LiveSync'), findsOneWidget);
  });
}
