import 'package:flutter/material.dart';
import '../theme/tandem_theme.dart';
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

/// TandemButton: High-contrast interactive control adhering to theme brightness and hit targets.
class TandemButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final TandemButtonVariant variant;
  final TandemButtonSize size;
  final bool isLoading;
  final IconData? icon;
  final bool autofocus;

  const TandemButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.variant = TandemButtonVariant.primary,
    this.size = TandemButtonSize.md,
    this.isLoading = false,
    this.icon,
    this.autofocus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final isEnabled = onPressed != null && !isLoading;

    final Color bg;
    final Color fg;
    final BorderSide? borderSide;

    switch (variant) {
      case TandemButtonVariant.primary:
        bg = t.linkDirect;
        fg = t.onPrimary;
        borderSide = null;
        break;
      case TandemButtonVariant.secondary:
        bg = t.surface;
        fg = t.text;
        borderSide = BorderSide(color: t.border, width: 0.5);
        break;
      case TandemButtonVariant.quiet:
        bg = TandemTokens.color_transparent;
        fg = t.linkDirect;
        borderSide = null;
        break;
      case TandemButtonVariant.destructive:
        bg = t.danger;
        fg = t.onPrimary;
        borderSide = null;
        break;
    }

    final double height = size == TandemButtonSize.lg
        ? TandemTokens.hit_target_mobile
        : (t.isTabletOrLarger ? 36.0 : TandemTokens.hit_target_mobile);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: TextButton(
        autofocus: autofocus,
        onPressed: isEnabled ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: isEnabled ? bg : t.border.withAlpha(90),
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(
            horizontal: TandemTokens.space_4,
            vertical: TandemTokens.space_2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TandemTokens.radius_control),
            side: borderSide ?? BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 14.0,
                height: 14.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              ),
              const SizedBox(width: TandemTokens.space_2),
            ] else if (icon != null) ...[
              Icon(icon, size: 16.0, color: fg),
              const SizedBox(width: TandemTokens.space_2),
            ],
            Text(
              label,
              style: TandemTokens.text_sm.copyWith(
                fontWeight: FontWeight.w600,
                color: isEnabled ? fg : t.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
