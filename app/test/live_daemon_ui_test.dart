import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/l10n/strings.dart';
import 'package:tandem/main.dart';
import 'package:tandem/screens/first_run_screen.dart';
import 'package:tandem/services/api_client.dart';
import 'package:tandem/state/tandem_controller.dart';

Future<void> _loadSystemFonts() async {
  Future<void> loadFontFile(String family, String path) async {
    final f = File(path);
    if (!f.existsSync()) return;
    final bytes = await f.readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  await loadFontFile('Roboto', '/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf');
  await loadFontFile('Ahem', '/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf');
  await loadFontFile('Atkinson Hyperlegible Next', '/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf');
  await loadFontFile('Familjen Grotesk', '/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf');
  await loadFontFile('monospace', '/usr/share/fonts/truetype/ubuntu/UbuntuMono-R.ttf');
  await loadFontFile(
    'MaterialIcons',
    '/tmp/tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
}

Future<int> _freeTcpPort() async {
  final srv = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = srv.port;
  await srv.close();
  return port;
}

Future<int> _freeUdpPort() async {
  final sock = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = sock.port;
  sock.close();
  return port;
}

Future<void> _captureLivePng(
  WidgetTester tester,
  Size size,
  String outPath,
  Widget root,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;

  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: root));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump();

  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final outFile = File(outPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsBytesSync(bytes!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TandemStrings.load();
    await _loadSystemFonts();
  });

  testWidgets(
      'Live UI against two real tandemd instances captures real empty, synced, and failing screenshots',
      (WidgetTester tester) async {
    final prevHttp = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = prevHttp);

    final outDir = '${Directory.current.path}/../design/screenshots/live';
    final tmpRoot = Directory.systemTemp.createTempSync('tandem-live-ui-');

    final goEnv = Map<String, String>.from(Platform.environment)
      ..['PATH'] = '/tmp/tools/go/bin:/tmp/tools:${Platform.environment['PATH'] ?? ''}'
      ..['GOCACHE'] = '/tmp/gocache'
      ..['CGO_ENABLED'] = '0';

    late Process procA;
    late Process procB;
    var aStarted = false;
    var bStarted = false;
    var bStopped = false;
    late int apiPortA;
    late int syncPortA;
    late int apiPortB;
    late int syncPortB;
    late Directory cfgA;
    late Directory cfgB;
    late Directory syncA;
    late Directory syncB;
    late ApiClient clientA;
    late ApiClient clientB;

    Future<void> stopProc(Process p) async {
      p.kill(ProcessSignal.sigterm);
      await p.exitCode.timeout(const Duration(seconds: 4), onTimeout: () {
        p.kill(ProcessSignal.sigkill);
        return -1;
      });
    }

    addTearDown(() async {
      await tester.runAsync(() async {
        if (aStarted) await stopProc(procA);
        if (bStarted && !bStopped) await stopProc(procB);
      });
      if (tmpRoot.existsSync()) tmpRoot.deleteSync(recursive: true);
    });

    Future<ApiClient> waitHealthy(String cfgDir, int port) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        final f = File('$cfgDir/api.key');
        if (f.existsSync()) {
          final key = f.readAsStringSync().trim();
          if (key.isNotEmpty) {
            final c = ApiClient(baseUrl: 'http://127.0.0.1:$port/api/v1', apiKey: key);
            try {
              final h = await c.getHealth();
              if (h.engineReady && h.syncPortOpen) return c;
            } catch (_) {}
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      throw StateError('tandemd on port $port did not become healthy');
    }

    // All real OS builds, sockets, and process startups MUST run inside tester.runAsync
    await tester.runAsync(() async {
      final binPath = '${tmpRoot.path}/tandemd';
      final buildRes = Process.runSync(
        'go',
        ['build', '-o', binPath, './cmd/tandemd'],
        workingDirectory: '../core',
        environment: goEnv,
      );
      expect(buildRes.exitCode, 0, reason: 'go build tandemd failed: ${buildRes.stderr}');

      apiPortA = await _freeTcpPort();
      syncPortA = await _freeTcpPort();
      final guiPortA = await _freeTcpPort();
      apiPortB = await _freeTcpPort();
      syncPortB = await _freeTcpPort();
      final guiPortB = await _freeTcpPort();
      final discPort = await _freeUdpPort();

      cfgA = Directory('${tmpRoot.path}/cfgA')..createSync();
      cfgB = Directory('${tmpRoot.path}/cfgB')..createSync();
      syncA = Directory('${tmpRoot.path}/syncA')..createSync();
      syncB = Directory('${tmpRoot.path}/syncB')..createSync();

      File('${syncA.path}/hello.txt').writeAsStringSync('live-tandem-sync-payload');
      File('${syncA.path}/notes.md').writeAsStringSync('verified via live tandemd');

      procA = await Process.start(
        binPath,
        [
          '-config', cfgA.path,
          '-bind', '127.0.0.1:$apiPortA',
          '-sync-port', '$syncPortA',
          '-discovery-port', '$discPort',
          '-engine-gui', '127.0.0.1:$guiPortA',
          '-device-name', 'LiveLaptopA',
          '-global-discovery=false',
          '-relays=false',
          '-nat=false',
        ],
        environment: goEnv,
      );
      aStarted = true;

      procB = await Process.start(
        binPath,
        [
          '-config', cfgB.path,
          '-bind', '127.0.0.1:$apiPortB',
          '-sync-port', '$syncPortB',
          '-discovery-port', '$discPort',
          '-engine-gui', '127.0.0.1:$guiPortB',
          '-device-name', 'LivePhoneB',
          '-global-discovery=false',
          '-relays=false',
          '-nat=false',
        ],
        environment: goEnv,
      );
      bStarted = true;

      clientA = await waitHealthy(cfgA.path, apiPortA);
      clientB = await waitHealthy(cfgB.path, apiPortB);
    });

    // 1. Live Empty Daemon State (FirstRunScreen) at 1920, 1280, 390
    final emptyCtrl = TandemController(client: clientA);
    await tester.runAsync(() => emptyCtrl.refreshAll());
    await _captureLivePng(
      tester,
      const Size(1920, 1080),
      '$outDir/empty-1920-light.png',
      TandemApp(controller: emptyCtrl, themeMode: ThemeMode.light),
    );
    expect(find.byType(FirstRunScreen), findsOneWidget);
    expect(find.text('LiveLaptopA'), findsOneWidget);

    await _captureLivePng(
      tester,
      const Size(1280, 800),
      '$outDir/empty-1280-dark.png',
      TandemApp(controller: emptyCtrl, themeMode: ThemeMode.dark),
    );
    await _captureLivePng(
      tester,
      const Size(390, 844),
      '$outDir/empty-390-light.png',
      TandemApp(controller: emptyCtrl, themeMode: ThemeMode.light),
    );
    emptyCtrl.dispose();

    // 2. Pair A & B over real TLS/BEP and sync a real folder with real files
    await tester.runAsync(() async {
      final stA = await clientA.getStatus();
      final stB = await clientB.getStatus();

      await clientA.pairDevice(
        deviceId: stB.myDeviceId,
        name: 'LivePhoneB',
        addressHint: 'tcp://127.0.0.1:$syncPortB',
      );
      await clientB.pairDevice(
        deviceId: stA.myDeviceId,
        name: 'LiveLaptopA',
        addressHint: 'tcp://127.0.0.1:$syncPortA',
      );

      final httpClient = HttpClient();
      Future<void> postFolder(int port, String key, String path, String peerId) async {
        final req = await httpClient.postUrl(Uri.parse('http://127.0.0.1:$port/api/v1/folders'));
        req.headers.set('Authorization', 'Bearer $key');
        req.headers.set('Content-Type', 'application/json');
        req.write(json.encode({
          'id': 'live-shared',
          'label': 'Live Photos',
          'path': path,
          'type': 'sendreceive',
          'sharedDevices': [peerId],
        }));
        final resp = await req.close();
        await resp.drain<void>();
      }

      await postFolder(apiPortA, clientA.apiKey, syncA.path, stB.myDeviceId);
      await postFolder(apiPortB, clientB.apiKey, syncB.path, stA.myDeviceId);
      httpClient.close();

      final deadline = DateTime.now().add(const Duration(seconds: 30));
      var synced = false;
      while (DateTime.now().isBefore(deadline)) {
        final dstFile = File('${syncB.path}/hello.txt');
        final devs = await clientA.getDevices();
        final direct = devs.any((d) => d.id == stB.myDeviceId && d.linkState == 'direct-local');
        if (dstFile.existsSync() &&
            dstFile.readAsStringSync() == 'live-tandem-sync-payload' &&
            direct) {
          synced = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(synced, isTrue, reason: 'Live daemons did not sync files & report direct-local');
    });

    final syncCtrl = TandemController(client: clientA);
    await tester.runAsync(() => syncCtrl.refreshAll());
    await _captureLivePng(
      tester,
      const Size(1920, 1080),
      '$outDir/synced-1920-light.png',
      TandemApp(controller: syncCtrl, themeMode: ThemeMode.light),
    );
    expect(find.text('Live Photos'), findsOneWidget);
    expect(find.text('LivePhoneB'), findsWidgets);
    expect(find.text('Direct, same network'), findsWidgets);

    await _captureLivePng(
      tester,
      const Size(1280, 800),
      '$outDir/synced-1280-light.png',
      TandemApp(controller: syncCtrl, themeMode: ThemeMode.light),
    );
    await _captureLivePng(
      tester,
      const Size(1280, 800),
      '$outDir/synced-1280-dark.png',
      TandemApp(controller: syncCtrl, themeMode: ThemeMode.dark),
    );
    await _captureLivePng(
      tester,
      const Size(390, 844),
      '$outDir/synced-390-light.png',
      TandemApp(controller: syncCtrl, themeMode: ThemeMode.light),
    );
    await _captureLivePng(
      tester,
      const Size(390, 844),
      '$outDir/synced-390-dark.png',
      TandemApp(controller: syncCtrl, themeMode: ThemeMode.dark),
    );
    syncCtrl.dispose();

    // 3. Failing / Offline Peer + Unauthorized 401 Daemon Error State
    await tester.runAsync(() async {
      await stopProc(procB);
      bStopped = true;
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(deadline)) {
        final devs = await clientA.getDevices();
        if (devs.any((d) => d.linkState == 'offline')) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    });

    final failCtrl = TandemController(client: clientA);
    await tester.runAsync(() => failCtrl.refreshAll());
    await _captureLivePng(
      tester,
      const Size(1280, 800),
      '$outDir/failing-1280-light.png',
      TandemApp(controller: failCtrl, themeMode: ThemeMode.light),
    );
    await _captureLivePng(
      tester,
      const Size(390, 844),
      '$outDir/failing-390-dark.png',
      TandemApp(controller: failCtrl, themeMode: ThemeMode.dark),
    );
    failCtrl.dispose();

    final badAuthCtrl = TandemController(
      client: ApiClient(baseUrl: 'http://127.0.0.1:$apiPortA/api/v1', apiKey: 'wrong-key'),
    );
    await tester.runAsync(() => badAuthCtrl.initialize());
    await _captureLivePng(
      tester,
      const Size(1280, 800),
      '$outDir/daemon-error-1280-light.png',
      TandemApp(controller: badAuthCtrl, themeMode: ThemeMode.light),
    );
    expect(find.text(TandemStrings.get('daemon.error.title')), findsOneWidget);
    badAuthCtrl.dispose();

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
