import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tandem/l10n/strings.dart';
import 'package:tandem/main.dart';
import 'package:tandem/models/models.dart';
import 'package:tandem/screens/folder_detail_screen.dart';
import 'package:tandem/screens/no_internet_helper_screen.dart';
import 'package:tandem/screens/pairing_screen.dart';
import 'package:tandem/services/api_client.dart';
import 'package:tandem/state/tandem_controller.dart';
import 'package:tandem/theme/tokens.dart';
import 'openapi_mock_validator.dart';

enum _MockScenario { empty, synced, failing, unreachable }

MockClient _buildScenarioMock(_MockScenario scenario) {
  return contractCheckedMock((http.Request request) async {
    if (scenario == _MockScenario.unreachable) {
      return http.Response('{"error":"unauthorized"}', 401);
    }
    final path = request.url.path;
    if (scenario == _MockScenario.failing && path.endsWith('/status')) {
      return http.Response(
        json.encode({
          'version': '0.3.0-dev',
          'myDeviceId': 'NODEA-1111111-2222222-3333333-4444444-5555555-6666666-7777777',
          'myDeviceName': 'node-alpha',
          'state': 'degraded',
          'hasInternet': false,
          'activeTransfers': 0,
          'syncPort': 22000,
          'discoveryPort': 21027,
        }),
        200,
      );
    }
    if (path.endsWith('/status')) {
      return http.Response(
        json.encode({
          'version': '0.3.0-dev',
          'myDeviceId': 'NODEA-1111111-2222222-3333333-4444444-5555555-6666666-7777777',
          'myDeviceName': 'node-alpha',
          'state': 'running',
          'hasInternet': scenario == _MockScenario.synced,
          'activeTransfers': scenario == _MockScenario.synced ? 1 : 0,
          'syncPort': 22000,
          'discoveryPort': 21027,
        }),
        200,
      );
    }
    if (path.endsWith('/health')) {
      if (scenario == _MockScenario.failing) {
        return http.Response(
          json.encode({
            'engineReady': true,
            'syncPortOpen': false,
            'firewallState': 'blocked',
            'firewallRemediation': 'Allow TCP/UDP 22000 and UDP 21027 in host firewall.',
            'firewallCommand': 'sudo ufw allow 22000 && sudo ufw allow 21027/udp',
            'discoveryWorks': false,
            'storageOk': false,
            'inotifyExhausted': true,
            'batteryOptimized': false,
          }),
          200,
        );
      }
      return http.Response(
        json.encode({
          'engineReady': true,
          'syncPortOpen': true,
          'firewallState': 'open',
          'firewallCommand': '',
          'discoveryWorks': true,
          'storageOk': true,
          'inotifyExhausted': false,
          'batteryOptimized': false,
        }),
        200,
      );
    }
    if (path.endsWith('/devices')) {
      if (scenario == _MockScenario.empty) {
        return http.Response('[]', 200);
      }
      if (scenario == _MockScenario.failing) {
        return http.Response(
          json.encode([
            {
              'id': 'NODEB-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG',
              'name': 'node-beta-laptop',
              'isPaired': true,
              'linkState': 'offline',
              'lastSeen': '12 minutes ago',
              'addresses': ['tcp://192.168.1.44:22000'],
              'uploadRateBytesPerSec': 0,
              'downloadRateBytesPerSec': 0,
            },
            {
              'id': 'NODEC-1111111-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF',
              'name': 'node-gamma-phone',
              'isPaired': true,
              'linkState': 'relayed',
              'lastSeen': 'Just now',
              'addresses': ['relay://198.51.100.10:22067'],
              'uploadRateBytesPerSec': 124000,
              'downloadRateBytesPerSec': 48000,
            },
          ]),
          200,
        );
      }
      return http.Response(
        json.encode([
          {
            'id': 'NODEB-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG',
            'name': 'node-beta-laptop',
            'isPaired': true,
            'linkState': 'direct-local',
            'lastSeen': 'Just now',
            'addresses': ['tcp://192.168.1.44:22000'],
            'uploadRateBytesPerSec': 28400000,
            'downloadRateBytesPerSec': 1420000,
          },
          {
            'id': 'NODEC-1111111-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF',
            'name': 'node-gamma-phone',
            'isPaired': true,
            'linkState': 'relayed',
            'lastSeen': '1 minute ago',
            'addresses': ['relay://198.51.100.10:22067'],
            'uploadRateBytesPerSec': 410000,
            'downloadRateBytesPerSec': 0,
          },
          {
            'id': 'NODED-2222222-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-AAAAAAA',
            'name': 'studio-desktop',
            'isPaired': false,
            'linkState': 'direct-local',
            'lastSeen': 'Just now',
            'addresses': ['tcp://192.168.1.99:22000'],
            'uploadRateBytesPerSec': 0,
            'downloadRateBytesPerSec': 0,
          },
        ]),
        200,
      );
    }
    if (path.endsWith('/pairing/code')) {
      return http.Response(
        json.encode({
          'deviceId': 'NODEA-1111111-2222222-3333333-4444444-5555555-6666666-7777777',
          'name': 'node-alpha',
          'qrPayload': 'tandem://pair?v=1&id=NODEA-1111111&name=node-alpha&code=482913',
          'shortCode': '482 913',
        }),
        200,
      );
    }
    if (path.endsWith('/folders')) {
      if (scenario == _MockScenario.empty) {
        return http.Response('[]', 200);
      }
      return http.Response(
        json.encode([
          {
            'id': 'fld-projects',
            'label': 'Projects',
            'path': '/home/user/Sync/Projects',
            'type': 'sendreceive',
            'state': scenario == _MockScenario.failing ? 'error' : 'syncing',
            'paused': false,
            'sharedDevices': ['NODEB-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG'],
            'totalBytes': 1073741824,
            'totalFiles': 1004,
            'needBytes': scenario == _MockScenario.failing ? 52428800 : 12582912,
            'trashCount': 2,
          },
          {
            'id': 'fld-photos',
            'label': 'Photos',
            'path': '/home/user/Pictures/Camera',
            'type': 'receiveonly',
            'state': 'idle',
            'paused': false,
            'sharedDevices': ['NODEC-1111111-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF'],
            'totalBytes': 482344960,
            'totalFiles': 312,
            'needBytes': 0,
            'trashCount': 0,
          },
        ]),
        200,
      );
    }
    if (path.endsWith('/errors')) {
      if (scenario == _MockScenario.failing) {
        return http.Response(
          json.encode([
            {
              'code': 'err.disk_full',
              'path': '/home/user/Sync/Projects/archive.bin',
              'message': 'Insufficient disk space on target filesystem.',
            }
          ]),
          200,
        );
      }
      return http.Response('[]', 200);
    }
    if (path.endsWith('/trash')) {
      return http.Response(
        json.encode([
          {
            'trashId': 'tr-1',
            'originalPath': 'draft-notes.txt',
            'deletedAt': '2026-11-25T11:10:00Z',
            'sizeBytes': 4096,
          }
        ]),
        200,
      );
    }
    if (path.endsWith('/send')) {
      if (scenario != _MockScenario.synced) return http.Response('[]', 200);
      return http.Response(
        json.encode([
          {
            'sessionId': 'snd-001',
            'targetDeviceId': 'NODEB-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG',
            'state': 'transferring',
            'filesSent': 3,
            'totalFiles': 5,
            'bytesSent': 18874368,
            'totalBytes': 31457280,
            'speedBytesPerSec': 24117248,
            'interfaceUsed': 'direct-local',
          }
        ]),
        200,
      );
    }
    return http.Response('{}', 200);
  });
}

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

Future<void> _captureWidgetPng(
  WidgetTester tester,
  Size logicalSize,
  String outPath,
  Widget root,
) async {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;

  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: root,
    ),
  );
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
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

  group('WS3 Screenshots & Keyboard Navigation', () {
    testWidgets('Captures 1920, 1280, 390 light/dark PNGs across empty, synced, and failing states',
        (WidgetTester tester) async {
      final outDir = '${Directory.current.path}/../design/screenshots';

      final specs = <({
        String name,
        Size size,
        ThemeMode theme,
        _MockScenario scenario,
      })>[
        (name: 'empty-1920-light', size: const Size(1920, 1080), theme: ThemeMode.light, scenario: _MockScenario.empty),
        (name: 'empty-1280-dark', size: const Size(1280, 800), theme: ThemeMode.dark, scenario: _MockScenario.empty),
        (name: 'empty-390-light', size: const Size(390, 844), theme: ThemeMode.light, scenario: _MockScenario.empty),
        (name: 'synced-1920-light', size: const Size(1920, 1080), theme: ThemeMode.light, scenario: _MockScenario.synced),
        (name: 'synced-1280-light', size: const Size(1280, 800), theme: ThemeMode.light, scenario: _MockScenario.synced),
        (name: 'synced-1280-dark', size: const Size(1280, 800), theme: ThemeMode.dark, scenario: _MockScenario.synced),
        (name: 'synced-390-light', size: const Size(390, 844), theme: ThemeMode.light, scenario: _MockScenario.synced),
        (name: 'synced-390-dark', size: const Size(390, 844), theme: ThemeMode.dark, scenario: _MockScenario.synced),
        (name: 'failing-1280-light', size: const Size(1280, 800), theme: ThemeMode.light, scenario: _MockScenario.failing),
        (name: 'failing-390-dark', size: const Size(390, 844), theme: ThemeMode.dark, scenario: _MockScenario.failing),
      ];

      for (final s in specs) {
        final ctrl = TandemController(
          client: ApiClient(apiKey: 'k', client: _buildScenarioMock(s.scenario)),
        );
        await _captureWidgetPng(
          tester,
          s.size,
          '$outDir/${s.name}.png',
          TandemApp(controller: ctrl, themeMode: s.theme),
        );
        ctrl.dispose();
        expect(File('$outDir/${s.name}.png').lengthSync(), greaterThan(1000));
      }

      // Also capture FolderDetail (disk full error banner + trash table)
      final failCtrl = TandemController(
        client: ApiClient(apiKey: 'k', client: _buildScenarioMock(_MockScenario.failing)),
      );
      await tester.runAsync(() => failCtrl.refreshAll());
      const folder = TandemFolder(
        id: 'fld-projects',
        label: 'Projects',
        path: '/home/user/Sync/Projects',
        type: 'sendreceive',
        state: 'error',
        paused: false,
        sharedDevices: ['NODEB-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG'],
        totalBytes: 1073741824,
        totalFiles: 1004,
        needBytes: 52428800,
        trashCount: 1,
      );
      await _captureWidgetPng(
        tester,
        const Size(1280, 800),
        '$outDir/folder-detail-error-1280-light.png',
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: TandemTokens.color_ground,
          ),
          home: FolderDetailScreen(controller: failCtrl, folder: folder),
        ),
      );
      failCtrl.dispose();

      // Capture Daemon Error (401/unreachable)
      final errCtrl = TandemController(
        client: ApiClient(apiKey: 'bad', client: _buildScenarioMock(_MockScenario.unreachable)),
      );
      await _captureWidgetPng(
        tester,
        const Size(1280, 800),
        '$outDir/daemon-error-1280-light.png',
        TandemApp(controller: errCtrl, themeMode: ThemeMode.light),
      );
      errCtrl.dispose();

      // Capture remaining screens (S4 Send, S5 Devices, S6 LinkStatus, S7 Pairing,
      // S8 NoInternetHelper, S9 HealthCheck failing, S10 Settings, S11 Activity)
      final syncCtrl = TandemController(
        client: ApiClient(apiKey: 'k', client: _buildScenarioMock(_MockScenario.synced)),
      );
      await _captureWidgetPng(
        tester,
        const Size(1280, 800),
        '$outDir/send-1280-light.png',
        TandemApp(controller: syncCtrl, themeMode: ThemeMode.light),
      );
      await tester.tap(find.text('Send').first);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
      {
        final boundary = tester
            .renderObject(find.byType(RepaintBoundary).first) as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.0);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          return data!.buffer.asUint8List();
        });
        File('$outDir/send-1280-light.png').writeAsBytesSync(bytes!);
      }

      await tester.tap(find.text('Devices').first);
      await tester.pump();
      {
        final boundary = tester
            .renderObject(find.byType(RepaintBoundary).first) as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.0);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          return data!.buffer.asUint8List();
        });
        File('$outDir/devices-1280-light.png').writeAsBytesSync(bytes!);
      }

      await tester.tap(find.text('Activity').first);
      await tester.pump();
      {
        final boundary = tester
            .renderObject(find.byType(RepaintBoundary).first) as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.0);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          return data!.buffer.asUint8List();
        });
        File('$outDir/activity-1280-light.png').writeAsBytesSync(bytes!);
      }

      await tester.tap(find.text('node-gamma-phone').first);
      await tester.pump();
      {
        final boundary = tester
            .renderObject(find.byType(RepaintBoundary).first) as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.0);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          return data!.buffer.asUint8List();
        });
        File('$outDir/link-status-relayed-1280-light.png').writeAsBytesSync(bytes!);
      }
      syncCtrl.dispose();

      // Failing HealthCheck & Dark Settings
      final healthCtrl = TandemController(
        client: ApiClient(apiKey: 'k', client: _buildScenarioMock(_MockScenario.failing)),
      );
      await _captureWidgetPng(
        tester,
        const Size(1280, 800),
        '$outDir/health-failing-1280-light.png',
        TandemApp(controller: healthCtrl, themeMode: ThemeMode.light),
      );
      await tester.tap(find.text('Health Check').first);
      await tester.pump();
      {
        final boundary = tester
            .renderObject(find.byType(RepaintBoundary).first) as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.0);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          return data!.buffer.asUint8List();
        });
        File('$outDir/health-failing-1280-light.png').writeAsBytesSync(bytes!);
      }

      await _captureWidgetPng(
        tester,
        const Size(1280, 800),
        '$outDir/settings-1280-dark.png',
        TandemApp(controller: healthCtrl, themeMode: ThemeMode.dark),
      );
      await tester.tap(find.text('Settings').first);
      await tester.pump();
      {
        final boundary = tester
            .renderObject(find.byType(RepaintBoundary).first) as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.0);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          return data!.buffer.asUint8List();
        });
        File('$outDir/settings-1280-dark.png').writeAsBytesSync(bytes!);
      }
      healthCtrl.dispose();

      // Pairing (desktop & mobile) and NoInternetHelper
      final pairCtrl = TandemController(
        client: ApiClient(apiKey: 'k', client: _buildScenarioMock(_MockScenario.synced)),
      );
      await tester.runAsync(() => pairCtrl.refreshAll());
      await _captureWidgetPng(
        tester,
        const Size(1280, 800),
        '$outDir/pairing-1280-light.png',
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          home: PairingScreen(controller: pairCtrl),
        ),
      );
      await _captureWidgetPng(
        tester,
        const Size(390, 844),
        '$outDir/pairing-390-light.png',
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          home: PairingScreen(controller: pairCtrl),
        ),
      );
      await _captureWidgetPng(
        tester,
        const Size(1280, 800),
        '$outDir/no-internet-1280-light.png',
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          home: const NoInternetHelperScreen(),
        ),
      );
      pairCtrl.dispose();

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('Desktop rail and keyboard traversal navigate Folders -> Send -> Devices -> Health',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ctrl = TandemController(
        client: ApiClient(apiKey: 'k', client: _buildScenarioMock(_MockScenario.synced)),
      );
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(TandemApp(controller: ctrl, themeMode: ThemeMode.light));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();

      expect(find.text('Projects'), findsOneWidget);

      await tester.tap(find.text('Projects').first);
      await tester.pump();
      expect(find.text('Deleted files (.tandem-trash)'), findsOneWidget);

      await tester.tap(find.text('Back').first);
      await tester.pump();
      expect(find.text('Choose folder'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      await tester.tap(find.text('Send').first);
      await tester.pump();
      expect(find.text('Send files'), findsWidgets);

      await tester.tap(find.text('Health Check').first);
      await tester.pump();
      expect(find.text('Run diagnostics again'), findsOneWidget);

      await tester.tap(find.text('node-gamma-phone').first);
      await tester.pump();
      expect(find.text('Through a relay (slower)'), findsWidgets);
    });
  });
}
