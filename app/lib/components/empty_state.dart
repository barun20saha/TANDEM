import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

/// EmptyState: Explains what this view is, why it is empty, and provides one clear action (Section 8.3 & 9.3).
class EmptyState extends StatelessWidget {
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  const EmptyState({
    Key? key,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420.0),
        child: Padding(
          padding: const EdgeInsets.all(TandemTokens.space_6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 48.0, color: TandemTokens.color_border),
                const SizedBox(height: TandemTokens.space_4),
              ],
              Text(
                title,
                style: TandemTokens.text_lg.copyWith(
                  fontWeight: FontWeight.w600,
                  color: TandemTokens.color_text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: TandemTokens.space_2),
              Text(
                description,
                style: TandemTokens.text_sm.copyWith(
                  color: TandemTokens.color_text.withOpacity(0.75),
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: TandemTokens.space_5),
                TandemButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  size: TandemButtonSize.lg,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
