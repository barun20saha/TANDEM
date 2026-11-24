import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/components/confirm_dialog.dart';

void main() {
  group('ConfirmDialog Widget Tests', () {
    testWidgets('triggers confirm and cancel callbacks properly', (WidgetTester tester) async {
      bool confirmed = false;
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmDialog(
              title: 'Stop syncing folder?',
              body: 'Files on this device will stay intact.',
              confirmLabel: 'Stop syncing',
              cancelLabel: 'Keep syncing',
              isDestructive: true,
              onConfirm: () => confirmed = true,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      expect(find.text('Stop syncing folder?'), findsOneWidget);
      expect(find.text('Files on this device will stay intact.'), findsOneWidget);
      expect(find.text('Stop syncing'), findsOneWidget);
      expect(find.text('Keep syncing'), findsOneWidget);

      await tester.tap(find.text('Stop syncing'));
      await tester.pump();
      expect(confirmed, isTrue);

      await tester.tap(find.text('Keep syncing'));
      await tester.pump();
      expect(cancelled, isTrue);
    });
  });
}
