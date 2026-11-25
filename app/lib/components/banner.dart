import 'package:flutter/material.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';

enum BannerVariant {
  info,
  warning,
  error,
}

/// BannerNotification: Inline persistent state/diagnostic banner with left semantic accent.
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

  Color _accentColor(TandemTheme t) {
    switch (variant) {
      case BannerVariant.info:
        return t.linkDirect;
      case BannerVariant.warning:
        return t.linkRelay;
      case BannerVariant.error:
        return t.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final accent = _accentColor(t);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: TandemTokens.space_1),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(TandemTokens.radius_control),
        border: Border.all(color: t.border, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TandemTokens.radius_control),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4.0, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TandemTokens.space_4,
                    vertical: TandemTokens.space_3,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          message,
                          style: t.bodyStyle.copyWith(fontSize: 14.0),
                        ),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(width: TandemTokens.space_3),
                        TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            foregroundColor: t.linkDirect,
                            padding: const EdgeInsets.symmetric(
                              horizontal: TandemTokens.space_2,
                            ),
                          ),
                          child: Text(
                            actionLabel!,
                            style: TandemTokens.text_sm.copyWith(
                              color: t.linkDirect,
                              fontWeight: FontWeight.w600,
                            ),
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
