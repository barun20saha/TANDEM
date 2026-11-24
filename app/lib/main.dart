import 'package:flutter/material.dart';
import 'theme/tokens.dart';
import 'screens/gallery_screen.dart';

void main() {
  runApp(const TandemApp());
}

class TandemApp extends StatelessWidget {
  const TandemApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tandem',
      debugShowCheckedModeBanner: false,

      // Light Theme mapping strictly to TandemTokens
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: TandemTokens.color_ground,
        colorScheme: const ColorScheme.light(
          background: TandemTokens.color_ground,
          surface: TandemTokens.color_surface,
          primary: TandemTokens.color_link_direct,
          error: TandemTokens.color_danger,
          onBackground: TandemTokens.color_text,
          onSurface: TandemTokens.color_text,
        ),
        fontFamily: 'Atkinson Hyperlegible Next',
        dividerTheme: const DividerThemeData(
          color: TandemTokens.color_border,
          thickness: 0.5,
        ),
      ),

      // Dark Theme mapping strictly to TandemTokens
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: TandemTokens.color_ground_dark,
        colorScheme: const ColorScheme.dark(
          background: TandemTokens.color_ground_dark,
          surface: TandemTokens.color_surface_dark,
          primary: TandemTokens.color_link_direct_dark,
          error: TandemTokens.color_danger_dark,
          onBackground: TandemTokens.color_text_dark,
          onSurface: TandemTokens.color_text_dark,
        ),
        fontFamily: 'Atkinson Hyperlegible Next',
        dividerTheme: const DividerThemeData(
          color: TandemTokens.color_border_dark,
          thickness: 0.5,
        ),
      ),

      themeMode: ThemeMode.system,
      home: const ComponentGalleryScreen(),
    );
  }
}
