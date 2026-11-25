import 'package:flutter/material.dart';
import 'tokens.dart';

/// Brightness- and viewport-aware token resolver built strictly on TandemTokens.
class TandemTheme {
  final bool isDark;
  final bool isDesktop;
  final bool isTabletOrLarger;

  const TandemTheme._({
    required this.isDark,
    required this.isDesktop,
    required this.isTabletOrLarger,
  });

  static TandemTheme of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final width = MediaQuery.sizeOf(context).width;
    return TandemTheme._(
      isDark: brightness == Brightness.dark,
      isDesktop: width >= 1024.0,
      isTabletOrLarger: width >= 768.0,
    );
  }

  Color get ground =>
      isDark ? TandemTokens.color_ground_dark : TandemTokens.color_ground;
  Color get surface =>
      isDark ? TandemTokens.color_surface_dark : TandemTokens.color_surface;
  Color get border =>
      isDark ? TandemTokens.color_border_dark : TandemTokens.color_border;
  Color get text =>
      isDark ? TandemTokens.color_text_dark : TandemTokens.color_text;
  Color get mutedText => text.withAlpha(isDark ? 178 : 165);
  Color get linkDirect => isDark
      ? TandemTokens.color_link_direct_dark
      : TandemTokens.color_link_direct;
  Color get linkRelay => isDark
      ? TandemTokens.color_link_relay_dark
      : TandemTokens.color_link_relay;
  Color get linkRelayText => isDark
      ? TandemTokens.color_link_relay_text_dark
      : TandemTokens.color_link_relay_text;
  Color get ok => isDark ? TandemTokens.color_ok_dark : TandemTokens.color_ok;
  Color get danger =>
      isDark ? TandemTokens.color_danger_dark : TandemTokens.color_danger;
  Color get onPrimary => isDark
      ? TandemTokens.color_on_primary_dark
      : TandemTokens.color_on_primary;

  /// Body size: 15px on desktop/tablet (>=768px), 16px on mobile (<768px).
  double get bodyFontSize => isTabletOrLarger ? 15.0 : 16.0;

  TextStyle get pageTitleStyle => TandemTokens.text_xl.copyWith(
        fontSize: isDesktop ? 22.0 : 20.0,
        fontWeight: FontWeight.w700,
        color: text,
        letterSpacing: -0.3,
      );

  TextStyle get sectionTitleStyle => TandemTokens.text_md.copyWith(
        fontSize: bodyFontSize,
        fontWeight: FontWeight.w700,
        color: text,
      );

  TextStyle get bodyStyle => TandemTokens.text_md.copyWith(
        fontSize: bodyFontSize,
        color: text,
        height: 1.4,
      );

  TextStyle get secondaryStyle => TandemTokens.text_sm.copyWith(
        fontSize: isTabletOrLarger ? 13.5 : 14.0,
        color: mutedText,
        height: 1.35,
      );

  TextStyle get captionStyle => TandemTokens.text_xs.copyWith(
        color: mutedText,
      );

  TextStyle get tabularBodyStyle => bodyStyle.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  TextStyle get monoStyle => TandemTokens.text_sm.copyWith(
        fontFamily: 'monospace',
        fontSize: 13.0,
        color: text,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Standard left-aligned workspace pane capped cleanly at 960px on wide screens.
class WorkspacePane extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  const WorkspacePane({
    Key? key,
    required this.child,
    this.padding,
    this.maxWidth = 960.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final resolvedPadding = padding ??
        EdgeInsets.symmetric(
          horizontal: t.isDesktop ? TandemTokens.space_5 : TandemTokens.space_4,
          vertical: TandemTokens.space_4,
        );

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: resolvedPadding,
          child: child,
        ),
      ),
    );
  }
}
