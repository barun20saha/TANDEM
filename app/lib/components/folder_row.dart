import 'package:flutter/material.dart';
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

/// FolderRow: Dense row representing a synchronized directory (Section 8.3).
/// Dense list row, strictly avoiding generic card-and-shadow defaults.
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
        return 'Syncing...';
      case FolderSyncState.paused:
        return 'Paused';
      case FolderSyncState.conflicts:
        return 'Conflicts detected';
      case FolderSyncState.error:
        return 'Sync error';
    }
  }

  Color get stateColor {
    switch (state) {
      case FolderSyncState.upToDate:
        return TandemTokens.color_ok;
      case FolderSyncState.syncing:
        return TandemTokens.color_link_direct;
      case FolderSyncState.paused:
        return TandemTokens.color_text;
      case FolderSyncState.conflicts:
      case FolderSyncState.error:
        return TandemTokens.color_danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
            // Folder Icon
            Icon(
              Icons.folder_outlined,
              size: 24.0,
              color: TandemTokens.color_link_direct,
            ),
            const SizedBox(width: TandemTokens.space_3),

            // Path & Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.isNotEmpty ? label : path,
                    style: TandemTokens.text_md.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    path,
                    style: TandemTokens.text_xs.copyWith(
                      color: TandemTokens.color_text.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Metadata: Type, Size, Device count, State
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  stateText,
                  style: TandemTokens.text_sm.copyWith(
                    color: stateColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  '$formattedSize · $deviceCount device${deviceCount == 1 ? '' : 's'}',
                  style: TandemTokens.text_xs.copyWith(
                    color: TandemTokens.color_text.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
