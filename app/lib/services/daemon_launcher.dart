import 'dart:io';
import 'api_client.dart';

class DaemonLaunchResult {
  final ApiClient client;
  final Process? process;

  const DaemonLaunchResult({required this.client, this.process});
}

/// Resolves config directory, reads api.key, starts bundled tandemd on desktop if needed,
/// and waits until /api/v1/health responds.
class DaemonLauncher {
  static const String _configuredDir = String.fromEnvironment('TANDEM_CONFIG_DIR');
  static const String _configuredBind = String.fromEnvironment('TANDEM_API_BIND', defaultValue: '127.0.0.1:8385');

  static String resolveConfigDir() {
    if (_configuredDir.isNotEmpty) {
      return _configuredDir;
    }
    final env = Platform.environment;
    if (Platform.isWindows) {
      final appData = env['APPDATA'] ?? env['USERPROFILE'] ?? '.';
      return '$appData\\tandem';
    }
    if (Platform.isMacOS) {
      final home = env['HOME'] ?? '.';
      return '$home/Library/Application Support/tandem';
    }
    final xdg = env['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      return '$xdg/tandem';
    }
    final home = env['HOME'] ?? '.';
    return '$home/.config/tandem';
  }

  static String? readApiKey(String configDir) {
    final f = File('$configDir${Platform.pathSeparator}api.key');
    if (!f.existsSync()) return null;
    final key = f.readAsStringSync().trim();
    return key.isEmpty ? null : key;
  }

  static String? findDaemonBinary() {
    final name = Platform.isWindows ? 'tandemd.exe' : 'tandemd';
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    final candidates = <String>[
      '$exeDir$sep$name',
      if (Platform.isMacOS) '$exeDir$sep..${sep}Helpers$sep$name',
      'bin$sep$name',
      if (!Platform.isWindows) '/usr/bin/$name',
      if (!Platform.isWindows) '/usr/local/bin/$name',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return name;
  }

  Future<DaemonLaunchResult> connectOrStart() async {
    const bind = _configuredBind;
    const baseUrl = 'http://$bind/api/v1';

    if (Platform.isAndroid) {
      // Android runs embedded native engine inside TandemService foreground service.
      final client = ApiClient(baseUrl: baseUrl, apiKey: '');
      try {
        await client.getHealth();
        return DaemonLaunchResult(client: client);
      } catch (e) {
        throw Exception('Android background sync service is not running ($e).');
      }
    }

    final cfgDir = resolveConfigDir();
    final existingKey = readApiKey(cfgDir);
    if (existingKey != null) {
      final probe = ApiClient(baseUrl: baseUrl, apiKey: existingKey);
      try {
        await probe.getHealth();
        return DaemonLaunchResult(client: probe);
      } catch (_) {
        // Daemon not running yet; launch it below.
      }
    }

    final bin = findDaemonBinary();
    if (bin == null) {
      throw Exception('Could not locate tandemd executable.');
    }

    Process proc;
    try {
      proc = await Process.start(
        bin,
        ['-config', cfgDir, '-bind', bind],
        mode: ProcessStartMode.detachedWithStdio,
      );
    } catch (e) {
      throw Exception('Failed to launch $bin: $e');
    }

    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      final key = readApiKey(cfgDir);
      if (key != null) {
        final client = ApiClient(baseUrl: baseUrl, apiKey: key);
        try {
          await client.getHealth();
          return DaemonLaunchResult(client: client, process: proc);
        } catch (_) {}
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    throw Exception('Timed out waiting for tandemd ($bin) on $bind to become healthy.');
  }
}
