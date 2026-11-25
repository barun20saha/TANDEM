import 'package:flutter/material.dart';
import 'components/buttons.dart';
import 'l10n/strings.dart';
import 'screens/home_shell.dart';
import 'state/tandem_controller.dart';
import 'theme/tandem_theme.dart';
import 'theme/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TandemApp());
}

class TandemApp extends StatefulWidget {
  final TandemController? controller;
  final ThemeMode themeMode;

  const TandemApp({
    Key? key,
    this.controller,
    this.themeMode = ThemeMode.system,
  }) : super(key: key);

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
        dividerTheme: const DividerThemeData(
          color: TandemTokens.color_border_dark,
          thickness: 0.5,
        ),
      ),
      themeMode: widget.themeMode,
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = TandemTheme.of(context);
          switch (_controller.connectionState) {
            case ViewLoadState.loading:
              return Scaffold(
                backgroundColor: t.ground,
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: t.linkDirect),
                      const SizedBox(height: TandemTokens.space_4),
                      Text(
                        TandemStrings.get('daemon.connecting'),
                        style: t.bodyStyle,
                      ),
                    ],
                  ),
                ),
              );
            case ViewLoadState.error:
              return Scaffold(
                backgroundColor: t.ground,
                body: SingleChildScrollView(
                  child: WorkspacePane(
                    maxWidth: 640.0,
                    padding: const EdgeInsets.all(TandemTokens.space_6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 36.0,
                          color: t.danger,
                        ),
                        const SizedBox(height: TandemTokens.space_4),
                        Text(
                          TandemStrings.get('daemon.error.title'),
                          style: t.pageTitleStyle,
                        ),
                        const SizedBox(height: TandemTokens.space_2),
                        Text(
                          _controller.connectionError ?? 'Daemon is unreachable.',
                          style: t.monoStyle.copyWith(color: t.mutedText),
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
              );
            case ViewLoadState.ready:
              return HomeShell(controller: _controller);
          }
        },
      ),
    );
  }
}
