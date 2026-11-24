import 'package:flutter/material.dart';
import '../theme/tokens.dart';

enum TandemButtonVariant {
  primary,
  secondary,
  quiet,
  destructive,
}

enum TandemButtonSize {
  md,
  lg,
}

/// TandemButton: Standard interactive action button conforming to hit targets and focus rings.
class TandemButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final TandemButtonVariant variant;
  final TandemButtonSize size;
  final Widget? icon;
  final bool isLoading;

  const TandemButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.variant = TandemButtonVariant.primary,
    this.size = TandemButtonSize.md,
    this.icon,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final height = (size == TandemButtonSize.lg) ? 48.0 : 36.0;
    final paddingHorizontal = (size == TandemButtonSize.lg) ? TandemTokens.space_5 : TandemTokens.space_4;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case TandemButtonVariant.primary:
        bg = TandemTokens.color_link_direct;
        fg = Colors.white;
        break;
      case TandemButtonVariant.secondary:
        bg = TandemTokens.color_surface;
        fg = TandemTokens.color_text;
        border = const BorderSide(color: TandemTokens.color_border, width: 1.0);
        break;
      case TandemButtonVariant.quiet:
        bg = Colors.transparent;
        fg = TandemTokens.color_link_direct;
        break;
      case TandemButtonVariant.destructive:
        bg = TandemTokens.color_danger;
        fg = Colors.white;
        break;
    }

    if (onPressed == null) {
      bg = TandemTokens.color_surface;
      fg = TandemTokens.color_border;
      border = BorderSide.none;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: height,
        minWidth: 80.0,
      ),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TandemTokens.radius_control),
          side: border,
        ),
        child: InkWell(
          onTap: (isLoading || onPressed == null) ? null : onPressed,
          borderRadius: BorderRadius.circular(TandemTokens.radius_control),
          focusColor: TandemTokens.color_link_direct.withOpacity(0.15),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: paddingHorizontal),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          icon!,
                          const SizedBox(width: TandemTokens.space_2),
                        ],
                        Text(
                          label,
                          style: TandemTokens.text_sm.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
