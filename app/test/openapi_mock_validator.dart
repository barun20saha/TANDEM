import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class OpenApiSpec {
  final Set<String> paths;
  final Map<String, Set<String>> requiredFields;
  final Map<String, Set<String>> schemaProps;

  OpenApiSpec({
    required this.paths,
    required this.requiredFields,
    required this.schemaProps,
  });

  static OpenApiSpec load([String relativePath = '../docs/openapi.yaml']) {
    final file = File(relativePath);
    if (!file.existsSync()) {
      throw StateError('OpenAPI spec not found at ${file.path}');
    }
    final lines = file.readAsLinesSync();
    final paths = <String>{};
    final requiredFields = <String, Set<String>>{};
    final schemaProps = <String, Set<String>>{};

    var section = '';
    var currentSchema = '';
    var inRequired = false;
    var inProperties = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final indent = line.length - line.trimLeft().length;

      if (indent == 0) {
        inRequired = false;
        inProperties = false;
        currentSchema = '';
        if (trimmed.startsWith('paths:')) {
          section = 'paths';
        } else if (trimmed.startsWith('components:')) {
          section = 'components';
        } else {
          section = '';
        }
        continue;
      }

      if (section == 'paths' &&
          indent == 2 &&
          trimmed.startsWith('/') &&
          trimmed.endsWith(':')) {
        paths.add(trimmed.substring(0, trimmed.length - 1));
        continue;
      }

      if (section == 'components') {
        if (indent == 2 && trimmed == 'schemas:') continue;
        if (indent == 4 && trimmed.endsWith(':')) {
          currentSchema = trimmed.substring(0, trimmed.length - 1);
          requiredFields.putIfAbsent(currentSchema, () => <String>{});
          schemaProps.putIfAbsent(currentSchema, () => <String>{});
          inRequired = false;
          inProperties = false;
          continue;
        }
        if (currentSchema.isNotEmpty) {
          if (indent == 6) {
            inRequired = trimmed == 'required:';
            inProperties = trimmed == 'properties:';
            continue;
          }
          if (inRequired && indent == 8 && trimmed.startsWith('- ')) {
            requiredFields[currentSchema]!.add(trimmed.substring(2).trim());
            continue;
          }
          if (inProperties && indent == 8 && trimmed.endsWith(':')) {
            schemaProps[currentSchema]!
                .add(trimmed.substring(0, trimmed.length - 1));
            continue;
          }
        }
      }
    }

    return OpenApiSpec(
      paths: paths,
      requiredFields: requiredFields,
      schemaProps: schemaProps,
    );
  }

  String? schemaForApiPath(String apiPath) {
    if (apiPath == '/status') return 'DaemonStatus';
    if (apiPath == '/health') return 'SystemHealth';
    if (apiPath == '/devices') return 'Device';
    if (apiPath == '/folders') return 'Folder';
    if (apiPath == '/send') return 'SendSession';
    if (apiPath == '/pairing/code') return 'PairingPayload';
    if (apiPath == '/pairing/confirm') return 'PairingResult';
    if (RegExp(r'^/folders/[^/]+/errors$').hasMatch(apiPath)) {
      return 'FolderError';
    }
    if (RegExp(r'^/folders/[^/]+/trash$').hasMatch(apiPath)) {
      return 'TrashItem';
    }
    if (RegExp(r'^/devices/[^/]+$').hasMatch(apiPath)) return 'Device';
    if (RegExp(r'^/folders/[^/]+$').hasMatch(apiPath)) return 'Folder';
    if (RegExp(r'^/send/[^/]+$').hasMatch(apiPath)) return 'SendSession';
    return null;
  }

  bool isKnownPath(String apiPath) {
    if (paths.contains(apiPath)) return true;
    for (final template in paths) {
      final pattern = '^${template.replaceAll(RegExp(r'\{[^}]+\}'), r'[^/]+')}\$';
      if (RegExp(pattern).hasMatch(apiPath)) return true;
    }
    return false;
  }

  void validateObject(String schemaName, Map<String, dynamic> obj) {
    final reqs = requiredFields[schemaName];
    if (reqs == null) {
      throw AssertionError('Unknown OpenAPI schema: $schemaName');
    }
    for (final r in reqs) {
      if (!obj.containsKey(r)) {
        throw AssertionError(
          'Response for $schemaName missing required OpenAPI field "$r": $obj',
        );
      }
    }
  }
}

/// Wraps a MockClient so any undocumented endpoint path or non-conforming JSON
/// payload fails the test immediately.
MockClient contractCheckedMock(
  Future<http.Response> Function(http.Request request) handler,
) {
  final spec = OpenApiSpec.load();
  return MockClient((http.Request request) async {
    var apiPath = request.url.path;
    if (apiPath.startsWith('/api/v1')) {
      apiPath = apiPath.substring('/api/v1'.length);
    }
    if (!spec.isKnownPath(apiPath)) {
      throw AssertionError(
        'Undocumented API path "${request.url.path}" not in docs/openapi.yaml',
      );
    }
    final resp = await handler(request);
    if (resp.statusCode >= 200 &&
        resp.statusCode < 300 &&
        resp.statusCode != 204 &&
        resp.body.trim().isNotEmpty) {
      final schema = spec.schemaForApiPath(apiPath);
      if (schema != null) {
        final decoded = json.decode(resp.body);
        if (decoded is Map<String, dynamic>) {
          spec.validateObject(schema, decoded);
        } else if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              spec.validateObject(schema, item);
            }
          }
        }
      }
    }
    return resp;
  });
}
