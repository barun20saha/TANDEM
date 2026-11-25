import 'package:flutter/material.dart';
import 'components/buttons.dart';
import 'l10n/strings.dart';
import 'screens/home_shell.dart';
import 'state/tandem_controller.dart';
import 'theme/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TandemApp());
}

class TandemApp extends StatefulWidget {
  final TandemController? controller;

  const TandemApp({Key? key, this.controller}) : super(key: key);

  @override
  State<TandemApp> createState() => _TandemAppState();
}

class _TandemAppState extends State<TandemApp> {
  late final TandemController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TandemController();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await TandemStrings.load();
    } catch (_) {}
    await _controller.initialize();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tandem',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: TandemTokens.color_ground,
        colorScheme: const ColorScheme.light(
          surface: TandemTokens.color_surface,
          primary: TandemTokens.color_link_direct,
          error: TandemTokens.color_danger,
          onSurface: TandemTokens.color_text,
        ),
        fontFamily: 'Atkinson Hyperlegible Next',
        dividerTheme: const DividerThemeData(
          color: TandemTokens.color_border,
          thickness: 0.5,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: TandemTokens.color_ground_dark,
        colorScheme: const ColorScheme.dark(
          surface: TandemTokens.color_surface_dark,
          primary: TandemTokens.color_link_direct_dark,
          error: TandemTokens.color_danger_dark,
          onSurface: TandemTokens.color_text_dark,
        ),
        fontFamily: 'Atkinson Hyperlegible Next',
        dividerTheme: const DividerThemeData(
          color: TandemTokens.color_border_dark,
          thickness: 0.5,
        ),
      ),
      themeMode: ThemeMode.system,
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          switch (_controller.connectionState) {
            case ViewLoadState.loading:
              return Scaffold(
                backgroundColor: TandemTokens.color_ground,
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: TandemTokens.space_4),
                      Text(
                        TandemStrings.get('daemon.connecting'),
                        style: TandemTokens.text_md,
                      ),
                    ],
                  ),
                ),
              );
            case ViewLoadState.error:
              return Scaffold(
                backgroundColor: TandemTokens.color_ground,
                body: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480.0),
                    child: Padding(
                      padding: const EdgeInsets.all(TandemTokens.space_6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48.0,
                            color: TandemTokens.color_danger,
                          ),
                          const SizedBox(height: TandemTokens.space_4),
                          Text(
                            TandemStrings.get('daemon.error.title'),
                            style: TandemTokens.text_xl,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: TandemTokens.space_2),
                          Text(
                            _controller.connectionError ?? 'Daemon is unreachable.',
                            style: TandemTokens.text_sm,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: TandemTokens.space_5),
                          TandemButton(
                            label: TandemStrings.get('daemon.error.retry'),
                            size: TandemButtonSize.lg,
                            onPressed: () => _controller.initialize(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            case ViewLoadState.ready:
              return HomeShell(controller: _controller);
          }
        },
      ),
    );
  }
}
