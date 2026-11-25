import 'package:flutter/material.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

/// ConfirmDialog: Explicit modal confirmation with safe default focus on destructive flows.
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
    final t = TandemTheme.of(context);

    return Dialog(
      backgroundColor: t.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: TandemTokens.space_4,
        vertical: TandemTokens.space_5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
        side: BorderSide(color: t.border, width: 0.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420.0),
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
                  color: t.text,
                ),
              ),
              const SizedBox(height: TandemTokens.space_3),
              Text(body, style: t.bodyStyle),
              const SizedBox(height: TandemTokens.space_6),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: TandemTokens.space_3,
                  runSpacing: TandemTokens.space_2,
                  alignment: WrapAlignment.end,
                  children: [
                    TandemButton(
                      label: cancelLabel,
                      variant: TandemButtonVariant.secondary,
                      autofocus: isDestructive,
                      onPressed: onCancel,
                    ),
                    TandemButton(
                      label: confirmLabel,
                      variant: isDestructive
                          ? TandemButtonVariant.destructive
                          : TandemButtonVariant.primary,
                      autofocus: !isDestructive,
                      onPressed: onConfirm,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
