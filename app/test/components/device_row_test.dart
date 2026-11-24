import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/components/device_row.dart';
import 'package:tandem/components/link_line.dart';

void main() {
  group('DeviceRow Widget Tests', () {
    testWidgets('displays device name, last seen, and responds to tap', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceRow(
              deviceId: 'DEV-1234',
              name: 'Pixel 9 Pro',
              isThisDevice: false,
              linkState: LinkLineState.directLocal,
              lastSeen: '2m ago',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Pixel 9 Pro'), findsOneWidget);
      expect(find.textContaining('2m ago'), findsOneWidget);

      await tester.tap(find.byType(DeviceRow));
      expect(tapped, isTrue);
    });

    testWidgets('shows This device badge when isThisDevice is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeviceRow(
              deviceId: 'LOCAL-DEV',
              name: 'Barun Laptop',
              isThisDevice: true,
              linkState: LinkLineState.directLocal,
              lastSeen: 'Active now',
            ),
          ),
        ),
      );

      expect(find.text('Barun Laptop'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);
    });
  });
}
