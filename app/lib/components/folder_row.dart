import 'package:flutter/material.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';

enum FolderType {
  sendReceive,
  sendOnly,
  receiveOnly,
}

enum FolderSyncState {
  upToDate,
  syncing,
  paused,
  conflicts,
  error,
}

/// FolderRow: Dense row representing a synchronized directory.
/// Displays column-aligned table columns on wide viewports and clean stacked metrics on mobile.
class FolderRow extends StatelessWidget {
  final String path;
  final String label;
  final FolderType type;
  final FolderSyncState state;
  final String formattedSize;
  final int deviceCount;
  final VoidCallback? onTap;

  const FolderRow({
    Key? key,
    required this.path,
    required this.label,
    this.type = FolderType.sendReceive,
    this.state = FolderSyncState.upToDate,
    this.formattedSize = '0 B',
    this.deviceCount = 1,
    this.onTap,
  }) : super(key: key);

  String get typeLabel {
    switch (type) {
      case FolderType.sendReceive:
        return 'Send & Receive';
      case FolderType.sendOnly:
        return 'Send only';
      case FolderType.receiveOnly:
        return 'Receive only';
    }
  }

  String get stateText {
    switch (state) {
      case FolderSyncState.upToDate:
        return 'Up to date';
      case FolderSyncState.syncing:
        return 'Syncing';
      case FolderSyncState.paused:
        return 'Paused';
      case FolderSyncState.conflicts:
        return 'Conflicts';
      case FolderSyncState.error:
        return 'Sync error';
    }
  }

  Color _stateColor(TandemTheme t) {
    switch (state) {
      case FolderSyncState.upToDate:
        return t.ok;
      case FolderSyncState.syncing:
        return t.linkDirect;
      case FolderSyncState.paused:
        return t.mutedText;
      case FolderSyncState.conflicts:
      case FolderSyncState.error:
        return t.danger;
    }
  }

  String _truncateMiddle(String str, int maxLen) {
    if (str.length <= maxLen) return str;
    final half = (maxLen - 3) ~/ 2;
    return '${str.substring(0, half)}...${str.substring(str.length - half)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final displayTitle = label.isNotEmpty ? label : path;
    final displayPath =
        t.isTabletOrLarger ? path : _truncateMiddle(path, 20);
    final peerLabel = '$deviceCount device${deviceCount == 1 ? '' : 's'}';
    final stateClr = _stateColor(t);

    return Material(
      color: t.surface,
      child: InkWell(
        onTap: onTap,
        focusColor: t.linkDirect.withAlpha(28),
        hoverColor: t.text.withAlpha(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: t.isTabletOrLarger ? TandemTokens.space_4 : TandemTokens.space_3,
            vertical: TandemTokens.space_3,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: t.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 20.0,
                color: t.linkDirect,
              ),
              const SizedBox(width: TandemTokens.space_3),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      displayPath,
                      style: t.monoStyle.copyWith(fontSize: 12.0, color: t.mutedText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (t.isTabletOrLarger) ...[
                const SizedBox(width: TandemTokens.space_3),
                SizedBox(
                  width: 118.0,
                  child: Text(
                    typeLabel,
                    style: t.secondaryStyle,
                  ),
                ),
                SizedBox(
                  width: 88.0,
                  child: Text(
                    formattedSize,
                    textAlign: TextAlign.right,
                    style: t.monoStyle.copyWith(fontSize: 13.0),
                  ),
                ),
                SizedBox(
                  width: 86.0,
                  child: Text(
                    peerLabel,
                    textAlign: TextAlign.right,
                    style: t.secondaryStyle,
                  ),
                ),
                const SizedBox(width: TandemTokens.space_3),
                SizedBox(
                  width: 90.0,
                  child: Text(
                    stateText,
                    textAlign: TextAlign.right,
                    style: TandemTokens.text_sm.copyWith(
                      color: stateClr,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: TandemTokens.space_2),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      stateText,
                      style: TandemTokens.text_sm.copyWith(
                        color: stateClr,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formattedSize,
                          style: t.monoStyle.copyWith(fontSize: 12.0, color: t.mutedText),
                        ),
                        const SizedBox(width: TandemTokens.space_3),
                        Text(
                          peerLabel,
                          style: t.captionStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
