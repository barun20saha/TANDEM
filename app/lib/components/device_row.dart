import 'package:flutter/material.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';
import 'link_line.dart';

enum DeviceSyncState {
  upToDate,
  syncing,
  paused,
  offline,
}

/// DeviceRow: Dense row representing this device or a paired/discovered peer.
/// Stacks LinkLine cleanly below device metadata when narrow (e.g. desktop rail or mobile).
class DeviceRow extends StatelessWidget {
  final String deviceId;
  final String name;
  final bool isThisDevice;
  final LinkLineState linkState;
  final DeviceSyncState syncState;
  final String lastSeen;
  final VoidCallback? onTap;
  final bool selected;

  const DeviceRow({
    Key? key,
    required this.deviceId,
    required this.name,
    this.isThisDevice = false,
    this.linkState = LinkLineState.directLocal,
    this.syncState = DeviceSyncState.upToDate,
    this.lastSeen = 'Just now',
    this.onTap,
    this.selected = false,
  }) : super(key: key);

  String _truncateMiddle(String str, int maxLen) {
    if (str.length <= maxLen) return str;
    final half = (maxLen - 3) ~/ 2;
    return '${str.substring(0, half)}...${str.substring(str.length - half)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final displayName = _truncateMiddle(name, 28);
    final minHeight = t.isTabletOrLarger
        ? TandemTokens.hit_target_desktop + 16.0
        : TandemTokens.hit_target_mobile + 8.0;

    final Color statusDotColor;
    if (syncState == DeviceSyncState.offline) {
      statusDotColor = t.border;
    } else {
      switch (linkState) {
        case LinkLineState.offline:
        case LinkLineState.connecting:
          statusDotColor = t.border;
          break;
        case LinkLineState.relayed:
          statusDotColor = t.linkRelay;
          break;
        case LinkLineState.directLocal:
        case LinkLineState.directInternet:
          statusDotColor =
              syncState == DeviceSyncState.syncing ? t.linkDirect : t.ok;
          break;
      }
    }

    return Material(
      color: selected ? t.linkDirect.withAlpha(20) : t.surface,
      child: InkWell(
        onTap: onTap,
        focusColor: t.linkDirect.withAlpha(28),
        hoverColor: t.text.withAlpha(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TandemTokens.space_4,
              vertical: TandemTokens.space_3,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: t.border, width: 0.5),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 420.0;
                final identityColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: TandemTokens.space_2,
                      runSpacing: 4.0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          displayName,
                          style: t.bodyStyle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isThisDevice)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: TandemTokens.space_2,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: t.ground,
                              borderRadius: BorderRadius.circular(
                                TandemTokens.radius_pill,
                              ),
                              border: Border.all(color: t.border, width: 0.5),
                            ),
                            child: Text(
                              'This device',
                              style: TandemTokens.text_xs.copyWith(
                                color: t.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      lastSeen,
                      style: t.captionStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isThisDevice && !wide) ...[
                      const SizedBox(height: TandemTokens.space_2),
                      LinkLine(
                        state: linkState,
                        length: 44.0,
                      ),
                    ],
                  ],
                );

                return Row(
                  crossAxisAlignment: wide
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: wide ? 0.0 : 6.0),
                      child: Container(
                        width: 8.0,
                        height: 8.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusDotColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: TandemTokens.space_3),
                    Expanded(child: identityColumn),
                    if (!isThisDevice && wide) ...[
                      const SizedBox(width: TandemTokens.space_3),
                      LinkLine(
                        state: linkState,
                        length: 56.0,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
