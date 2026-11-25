import 'package:flutter/material.dart';
import '../theme/tokens.dart';

enum BannerVariant {
  info,
  warning,
  error,
}

/// Banner: Inline persistent notification explaining a system state with at most one action (Section 8.3 & 9.3).
class BannerNotification extends StatelessWidget {
  final String message;
  final BannerVariant variant;
  final String? actionLabel;
  final VoidCallback? onAction;

  const BannerNotification({
    Key? key,
    required this.message,
    this.variant = BannerVariant.warning,
    this.actionLabel,
    this.onAction,
  }) : super(key: key);

  Color get borderColor {
    switch (variant) {
      case BannerVariant.info:
        return TandemTokens.color_link_direct;
      case BannerVariant.warning:
        return TandemTokens.color_link_relay;
      case BannerVariant.error:
        return TandemTokens.color_danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: TandemTokens.space_4,
        vertical: TandemTokens.space_2,
      ),
      decoration: BoxDecoration(
        color: TandemTokens.color_surface,
        borderRadius: BorderRadius.circular(TandemTokens.radius_control),
        border: Border.all(color: TandemTokens.color_border, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TandemTokens.radius_control),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4.0, color: borderColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(TandemTokens.space_3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          message,
                          style: TandemTokens.text_sm,
                        ),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(width: TandemTokens.space_3),
                        TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            foregroundColor: TandemTokens.color_link_direct,
                            padding: const EdgeInsets.symmetric(horizontal: TandemTokens.space_2),
                          ),
                          child: Text(
                            actionLabel!,
                            style: TandemTokens.text_sm.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
