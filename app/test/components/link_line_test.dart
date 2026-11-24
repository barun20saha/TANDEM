import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/components/link_line.dart';
import 'package:tandem/theme/tokens.dart';

void main() {
  group('LinkLine Widget Tests', () {
    testWidgets('renders direct local link with solid green styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LinkLine(
                state: LinkLineState.directLocal,
                length: 120.0,
              ),
            ),
          ),
        ),
      );

      final linkFinder = find.byType(LinkLine);
      expect(linkFinder, findsOneWidget);

      final semantics = tester.getSemantics(linkFinder);
      expect(semantics.label, contains('Direct'));
    });

    testWidgets('renders relayed link with dashed amber styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LinkLine(
                state: LinkLineState.relayed,
                length: 120.0,
              ),
            ),
          ),
        ),
      );

      final linkFinder = find.byType(LinkLine);
      expect(linkFinder, findsOneWidget);

      final semantics = tester.getSemantics(linkFinder);
      expect(semantics.label, contains('Through a relay'));
    });
  });
}
