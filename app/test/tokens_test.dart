import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/theme/tokens.dart';

void main() {
  group('TandemTokens Design System', () {
    test('verifies primary direct link color', () {
      expect(TandemTokens.color_link_direct.value, 0xFF2358D6);
    });

    test('verifies relay link color', () {
      expect(TandemTokens.color_link_relay.value, 0xFFB97A0B);
    });

    test('verifies spacing scale is strict 4pt base grid', () {
      expect(TandemTokens.space_1, 4.0);
      expect(TandemTokens.space_2, 8.0);
      expect(TandemTokens.space_3, 12.0);
      expect(TandemTokens.space_4, 16.0);
      expect(TandemTokens.space_5, 24.0);
      expect(TandemTokens.space_6, 32.0);
      expect(TandemTokens.space_7, 48.0);
    });

    test('verifies radius tokens', () {
      expect(TandemTokens.radius_control, 4.0);
      expect(TandemTokens.radius_panel, 10.0);
      expect(TandemTokens.radius_pill, 999.0);
    });
  });
}
