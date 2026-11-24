import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/theme/tokens.dart';

void main() {
  group('TandemTokens Design System', () {
    test('verifies primary direct link color is solid green', () {
      expect(TandemTokens.color_link_direct.value, 0xFF10B981);
    });

    test('verifies relay link color is amber', () {
      expect(TandemTokens.color_link_relay.value, 0xFFF59E0B);
    });

    test('verifies spacing scale is strict 8pt grid based', () {
      expect(TandemTokens.space_1, 4.0);
      expect(TandemTokens.space_2, 8.0);
      expect(TandemTokens.space_3, 12.0);
      expect(TandemTokens.space_4, 16.0);
      expect(TandemTokens.space_5, 24.0);
      expect(TandemTokens.space_6, 32.0);
      expect(TandemTokens.space_7, 48.0);
    });

    test('verifies border radius tokens', () {
      expect(TandemTokens.radius_card, 8.0);
      expect(TandemTokens.radius_panel, 12.0);
      expect(TandemTokens.radius_button, 8.0);
    });
  });
}
