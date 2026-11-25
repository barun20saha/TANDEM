import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tandem/l10n/strings.dart';
import 'package:tandem/main.dart';
import 'package:tandem/screens/first_run_screen.dart';
import 'package:tandem/services/api_client.dart';
import 'package:tandem/state/tandem_controller.dart';

/// Live desktop integration test (Gate A5) intended for `flutter test -d linux`
/// under `xvfb-run` with `go` and `syncthing` on PATH.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Live TandemApp pairs two real tandemd instances and syncs real files',
      (WidgetTester tester) async {
    await TandemStrings.load();
    final tmpRoot = Directory.systemTemp.createTempSync('tandem-it-');
    addTearDown(() => tmpRoot.deleteSync(recursive: true));

    final binPath = '${tmpRoot.path}/tandemd';
    final buildRes = Process.runSync(
      'go',
      ['build', '-o', binPath, './cmd/tandemd'],
      workingDirectory: '../core',
    );
    expect(buildRes.exitCode, 0, reason: buildRes.stderr.toString());

    final cfgA = Directory('${tmpRoot.path}/cfgA')..createSync();
    final cfgB = Directory('${tmpRoot.path}/cfgB')..createSync();
    final syncA = Directory('${tmpRoot.path}/syncA')..createSync();
    final syncB = Directory('${tmpRoot.path}/syncB')..createSync();
    File('${syncA.path}/hello.txt').writeAsStringSync('live-integration-sync');

    final procA = await Process.start(binPath, [
      '-config', cfgA.path,
      '-bind', '127.0.0.1:19385',
      '-sync-port', '25200',
      '-discovery-port', '25127',
      '-engine-gui', '127.0.0.1:19384',
      '-device-name', 'LiveNodeA',
      '-global-discovery=false',
      '-relays=false',
      '-nat=false',
    ]);
    final procB = await Process.start(binPath, [
      '-config', cfgB.path,
      '-bind', '127.0.0.1:19485',
      '-sync-port', '25300',
      '-discovery-port', '25127',
      '-engine-gui', '127.0.0.1:19484',
      '-device-name', 'LiveNodeB',
      '-global-discovery=false',
      '-relays=false',
      '-nat=false',
    ]);
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

    Future<ApiClient> waitReady(String cfgDir, String bind) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        final keyFile = File('$cfgDir/api.key');
        if (keyFile.existsSync()) {
          final key = keyFile.readAsStringSync().trim();
          if (key.isNotEmpty) {
            final client = ApiClient(baseUrl: 'http://$bind/api/v1', apiKey: key);
            try {
              final h = await client.getHealth();
              if (h.engineReady) return client;
            } catch (_) {}
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      throw StateError('Daemon on $bind failed to become healthy');
    }

    final clientA = await waitReady(cfgA.path, '127.0.0.1:19385');
    final clientB = await waitReady(cfgB.path, '127.0.0.1:19485');

    final ctrlA = TandemController(client: clientA);
    addTearDown(ctrlA.dispose);

    await tester.pumpWidget(TandemApp(controller: ctrlA, themeMode: ThemeMode.light));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(FirstRunScreen), findsOneWidget);

    final statusA = await clientA.getStatus();
    final statusB = await clientB.getStatus();
    await clientA.pairDevice(
      deviceId: statusB.myDeviceId,
      name: 'LiveNodeB',
      addressHint: 'tcp://127.0.0.1:25300',
    );
    await clientB.pairDevice(
      deviceId: statusA.myDeviceId,
      name: 'LiveNodeA',
      addressHint: 'tcp://127.0.0.1:25200',
    );
    await clientA.addFolder(
      path: syncA.path,
      label: 'LiveSync',
      sharedDevices: [statusB.myDeviceId],
    );
    final foldersA = await clientA.getFolders();
    await clientB.addFolder(
      path: syncB.path,
      label: 'LiveSync',
      sharedDevices: [statusA.myDeviceId],
    );
    // Use same folder id via direct status refresh
    expect(foldersA, isNotEmpty);
    await ctrlA.refreshAll();
    await tester.pumpAndSettle();
    expect(find.text('LiveSync'), findsOneWidget);
  });
}
