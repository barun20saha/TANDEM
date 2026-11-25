import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'openapi_mock_validator.dart';

void main() {
  test('Flutter ApiClient routes and models match docs/openapi.yaml', () {
    final spec = OpenApiSpec.load();

    final apiClientSrc = File('lib/services/api_client.dart').readAsStringSync();
    for (final route in const [
      '/status',
      '/health',
      '/devices',
      '/folders',
      '/errors',
      '/trash',
      '/trash/restore',
      '/send',
      '/pairing/code',
      '/pairing/confirm',
      '/events',
    ]) {
      expect(apiClientSrc.contains(route), isTrue,
          reason: 'ApiClient missing route $route');
    }

    for (final expectedPath in const [
      '/status',
      '/health',
      '/devices',
      '/devices/{deviceId}',
      '/folders',
      '/folders/{folderId}',
      '/folders/{folderId}/errors',
      '/folders/{folderId}/trash',
      '/folders/{folderId}/trash/restore',
      '/send',
      '/send/{sessionId}',
      '/pairing/code',
      '/pairing/confirm',
      '/events',
    ]) {
      expect(spec.paths.contains(expectedPath), isTrue,
          reason: 'openapi.yaml missing path $expectedPath');
    }

    final modelsSrc = File('lib/models/models.dart').readAsStringSync();
    for (final field in spec.schemaProps['DaemonStatus']!) {
      expect(modelsSrc.contains("'$field'"), isTrue,
          reason: 'DaemonStatus missing $field');
    }
    for (final field in spec.schemaProps['SystemHealth']!) {
      expect(modelsSrc.contains("'$field'"), isTrue,
          reason: 'SystemHealth missing $field');
    }
    for (final field in spec.schemaProps['SendSession']!) {
      expect(modelsSrc.contains("'$field'"), isTrue,
          reason: 'SendSession missing $field');
    }
  });
}
