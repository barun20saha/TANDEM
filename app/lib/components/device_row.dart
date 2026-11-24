import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'link_line.dart';

enum DeviceSyncState {
  upToDate,
  syncing,
  paused,
  offline,
}

/// DeviceRow: Dense list row representing a local or remote paired device (Section 8.3).
class DeviceRow extends StatelessWidget {
  final String deviceId;
  final String name;
  final bool isThisDevice;
  final LinkLineState linkState;
  final DeviceSyncState syncState;
  final String lastSeen;
  final VoidCallback? onTap;

  const DeviceRow({
    Key? key,
    required this.deviceId,
    required this.name,
    this.isThisDevice = false,
    this.linkState = LinkLineState.directLocal,
    this.syncState = DeviceSyncState.upToDate,
    this.lastSeen = 'Just now',
    this.onTap,
  }) : super(key: key);

  String _truncateMiddle(String str, int maxLen) {
    if (str.length <= maxLen) return str;
    final half = (maxLen - 3) ~/ 2;
    return '${str.substring(0, half)}...${str.substring(str.length - half)}';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _truncateMiddle(name, 28);

    return InkWell(
      onTap: onTap,
      focusColor: TandemTokens.color_link_direct.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TandemTokens.space_4,
          vertical: TandemTokens.space_3,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: TandemTokens.color_border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Status Indicator Dot
            Container(
              width: 8.0,
              height: 8.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: linkState == LinkLineState.offline
                    ? TandemTokens.color_border
                    : (syncState == DeviceSyncState.syncing
                        ? TandemTokens.color_link_direct
                        : TandemTokens.color_ok),
              ),
            ),
            const SizedBox(width: TandemTokens.space_3),

            // Device Name & ID
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        displayName,
                        style: TandemTokens.text_md.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isThisDevice) ...[
                        const SizedBox(width: TandemTokens.space_2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TandemTokens.space_2,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: TandemTokens.color_surface,
                            borderRadius: BorderRadius.circular(TandemTokens.radius_pill),
                            border: Border.all(color: TandemTokens.color_border, width: 0.5),
                          ),
                          child: Text(
                            'This device',
                            style: TandemTokens.text_xs.copyWith(
                              color: TandemTokens.color_text,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    'Last seen $lastSeen',
                    style: TandemTokens.text_xs.copyWith(
                      color: TandemTokens.color_text.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Link status line indicator
            if (!isThisDevice)
              LinkLine(
                state: linkState,
                length: 60.0,
              ),
          ],
        ),
      ),
    );
  }
}
