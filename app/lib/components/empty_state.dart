import 'package:flutter/material.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

/// EmptyState: Left-aligned, honest 3-line guidance when a view has zero real items.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520.0),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.isDesktop ? TandemTokens.space_5 : TandemTokens.space_4,
            vertical: TandemTokens.space_6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32.0, color: t.mutedText),
              const SizedBox(height: TandemTokens.space_3),
              Text(
                title,
                style: t.pageTitleStyle.copyWith(fontSize: 20.0),
              ),
              const SizedBox(height: TandemTokens.space_2),
              Text(description, style: t.secondaryStyle),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: TandemTokens.space_4),
                TandemButton(
                  label: actionLabel!,
                  variant: TandemButtonVariant.primary,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
