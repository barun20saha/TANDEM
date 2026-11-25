import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tandem/l10n/strings.dart';
import 'package:tandem/main.dart';
import 'package:tandem/screens/activity_screen.dart';
import 'package:tandem/screens/devices_screen.dart';
import 'package:tandem/screens/first_run_screen.dart';
import 'package:tandem/screens/folders_screen.dart';
import 'package:tandem/screens/health_check_screen.dart';
import 'package:tandem/screens/send_screen.dart';
import 'package:tandem/services/api_client.dart';
import 'package:tandem/state/tandem_controller.dart';
import 'openapi_mock_validator.dart';

MockClient _emptyDaemonMock({bool failAll = false}) {
  return contractCheckedMock((http.Request request) async {
    if (failAll) {
      return http.Response('{"error":"unauthorized"}', 401);
    }
    final path = request.url.path;
    if (path.endsWith('/status')) {
      return http.Response(
        json.encode({
          'version': '0.2.3-test',
          'myDeviceId': 'TESTDEV-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG',
          'myDeviceName': 'workstation-a',
          'state': 'running',
          'hasInternet': false,
          'activeTransfers': 0,
          'syncPort': 22000,
          'discoveryPort': 21027,
        }),
        200,
      );
    }
    if (path.endsWith('/health')) {
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
    if (path.endsWith('/devices') ||
        path.endsWith('/folders') ||
        path.endsWith('/send')) {
      return http.Response('[]', 200);
    }
    if (path.endsWith('/pairing/code')) {
      return http.Response(
        json.encode({
          'deviceId': 'TESTDEV-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG',
          'name': 'workstation-a',
          'qrPayload': 'tandem://pair?v=1&id=TESTDEV&code=123456',
          'shortCode': '123 456',
        }),
        200,
      );
    }
    return http.Response('{}', 200);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TandemStrings.load();
  });

  group('Real Daemon UI Empty & Error States (WS2)', () {
    testWidgets('TandemApp opens on FirstRunScreen when daemon has zero devices & folders',
        (WidgetTester tester) async {
      final client = ApiClient(apiKey: 'test-key', client: _emptyDaemonMock());
      final controller = TandemController(client: client);
      addTearDown(controller.dispose);

      await tester.pumpWidget(TandemApp(controller: controller));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      expect(find.byType(FirstRunScreen), findsOneWidget);
      expect(find.textContaining('workstation-a'), findsOneWidget);
      expect(find.textContaining('Tandem Component Gallery'), findsNothing);
      expect(find.textContaining('Pixel'), findsNothing);
      expect(find.textContaining('Framework'), findsNothing);
      expect(find.textContaining('Barun'), findsNothing);
    });

    testWidgets('TandemApp displays error state & retry button when daemon fails',
        (WidgetTester tester) async {
      final client =
          ApiClient(apiKey: 'bad-key', client: _emptyDaemonMock(failAll: true));
      final controller = TandemController(client: client);
      addTearDown(controller.dispose);

      await tester.pumpWidget(TandemApp(controller: controller));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      expect(find.text(TandemStrings.get('daemon.error.title')), findsOneWidget);
      expect(find.text(TandemStrings.get('daemon.error.retry')), findsOneWidget);
    });

    testWidgets('Individual screens render honest empty states with no invented data',
        (WidgetTester tester) async {
      final client = ApiClient(apiKey: 'test-key', client: _emptyDaemonMock());
      final controller = TandemController(client: client);
      addTearDown(controller.dispose);
      await controller.refreshAll();

      await tester.pumpWidget(
        MaterialApp(
          home: FoldersScreen(
            folders: controller.folders,
            onAddFolder: () {},
          ),
        ),
      );
      expect(find.text('No synced folders yet'), findsOneWidget);
      expect(find.textContaining('Pixel'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: DevicesScreen(
            status: controller.status,
            devices: controller.devices,
            onPairDevice: () {},
          ),
        ),
      );
      expect(find.text('No paired devices'), findsOneWidget);
      expect(find.textContaining('workstation-a'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: SendScreen(
            pairedDevices: const [],
            sessions: const [],
            onInitiateSend: (_, __) async {},
          ),
        ),
      );
      expect(find.text('Nothing to send yet'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(home: ActivityScreen(controller: controller)),
      );
      expect(find.text('No activity yet'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(home: HealthCheckScreen(controller: controller)),
      );
      expect(find.text(TandemStrings.get('health.all_clear')), findsOneWidget);
    });
  });
}
