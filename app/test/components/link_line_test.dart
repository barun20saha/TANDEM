import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/components/link_line.dart';

void main() {
  group('LinkLine Widget Tests', () {
    testWidgets('renders direct local link with text label', (WidgetTester tester) async {
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

      expect(find.byType(LinkLine), findsOneWidget);
      expect(find.text('Direct, same network'), findsOneWidget);
    });

    testWidgets('renders relayed link with explanation label', (WidgetTester tester) async {
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

      expect(find.byType(LinkLine), findsOneWidget);
      expect(find.text('Through a relay (slower)'), findsOneWidget);
    });
  });
}
