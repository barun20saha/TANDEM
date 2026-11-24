import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/components/folder_row.dart';

void main() {
  group('FolderRow Widget Tests', () {
    testWidgets('renders label, path, size, and device count', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderRow(
              path: '/home/barun/Documents/Work',
              label: 'Work Documents',
              formattedSize: '1.4 GB',
              deviceCount: 2,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Work Documents'), findsOneWidget);
      expect(find.text('/home/barun/Documents/Work'), findsOneWidget);
      expect(find.text('1.4 GB • 2 devices'), findsOneWidget);

      await tester.tap(find.byType(FolderRow));
      expect(tapped, isTrue);
    });
  });
}
