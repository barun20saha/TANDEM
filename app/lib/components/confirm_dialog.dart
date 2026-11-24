import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

/// ConfirmDialog: Modal confirmation dialog with action-oriented buttons (Section 8.3 & 9.3).
/// Safe action holds default focus on destructive dialogs.
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmDialog({
    Key? key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    this.isDestructive = false,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TandemTokens.color_surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
        side: const BorderSide(color: TandemTokens.color_border, width: 0.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400.0),
        child: Padding(
          padding: const EdgeInsets.all(TandemTokens.space_5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TandemTokens.text_lg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: TandemTokens.space_3),
              Text(
                body,
                style: TandemTokens.text_md,
              ),
              const SizedBox(height: TandemTokens.space_6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TandemButton(
                    label: cancelLabel,
                    variant: TandemButtonVariant.secondary,
                    onPressed: onCancel,
                  ),
                  const SizedBox(width: TandemTokens.space_3),
                  TandemButton(
                    label: confirmLabel,
                    variant: isDestructive
                        ? TandemButtonVariant.destructive
                        : TandemButtonVariant.primary,
                    onPressed: onConfirm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
