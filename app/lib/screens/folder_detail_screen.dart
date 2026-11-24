import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../components/buttons.dart';
import '../components/banner.dart';
import '../components/confirm_dialog.dart';

/// Screen S3: Folder Detail (Section 10.1).
/// Shows files, sharing devices, conflicts, trash retention, and folder sync mode.
class FolderDetailScreen extends StatefulWidget {
  final String folderId;
  final String folderLabel;
  final String folderPath;
  final String folderType; // sendreceive, sendonly, receiveonly
  final int sharedDeviceCount;
  final int conflictCount;
  final int trashFileCount;
  final String trashSize;

  const FolderDetailScreen({
    Key? key,
    required this.folderId,
    required this.folderLabel,
    required this.folderPath,
    this.folderType = 'sendreceive',
    this.sharedDeviceCount = 2,
    this.conflictCount = 0,
    this.trashFileCount = 3,
    this.trashSize = '14.2 MB',
  }) : super(key: key);

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  late String _currentType;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _currentType = widget.folderType;
  }

  void _showStopSyncDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Stop syncing folder?',
        body: 'Tandem will stop syncing "${widget.folderLabel}". Files on this device will stay intact, and deleted files remain in trash for 30 days.',
        confirmLabel: 'Stop syncing',
        cancelLabel: 'Keep syncing',
        isDestructive: true,
        onConfirm: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: Text(widget.folderLabel),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: TandemTokens.space_3),
            child: TandemButton(
              label: _isPaused ? 'Resume' : 'Pause',
              variant: TandemButtonVariant.secondary,
              onPressed: () => setState(() => _isPaused = !_isPaused),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(TandemTokens.space_4),
        children: [
          if (widget.conflictCount > 0) ...[
            BannerNotification(
              title: '${widget.conflictCount} file conflicts found',
              body: 'Different edits were made to files at the same time. Both copies have been preserved safely.',
              severity: BannerSeverity.warning,
              actionLabel: 'Review conflicts',
              onAction: () {},
            ),
            const SizedBox(height: TandemTokens.space_4),
          ],

          // Path & Metadata Card
          Container(
            padding: const EdgeInsets.all(TandemTokens.space_4),
            decoration: BoxDecoration(
              color: TandemTokens.color_surface,
              borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
              border: Border.all(color: TandemTokens.color_border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local folder path',
                  style: TandemTokens.text_xs.copyWith(
                    color: TandemTokens.color_text.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: TandemTokens.space_1),
                Text(
                  widget.folderPath,
                  style: TandemTokens.text_sm.copyWith(
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
                const Divider(height: TandemTokens.space_5, color: TandemTokens.color_border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sync mode', style: TandemTokens.text_sm),
                    DropdownButton<String>(
                      value: _currentType,
                      underline: const SizedBox(),
                      dropdownColor: TandemTokens.color_surface,
                      items: const [
                        DropdownMenuItem(
                          value: 'sendreceive',
                          child: Text('Send & Receive'),
                        ),
                        DropdownMenuItem(
                          value: 'sendonly',
                          child: Text('Send only'),
                        ),
                        DropdownMenuItem(
                          value: 'receiveonly',
                          child: Text('Receive only'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _currentType = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: TandemTokens.space_4),

          // Trash & Recovery Section (Section 4.8 & Rule 6)
          Container(
            padding: const EdgeInsets.all(TandemTokens.space_4),
            decoration: BoxDecoration(
              color: TandemTokens.color_surface,
              borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
              border: Border.all(color: TandemTokens.color_border, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.restore_from_trash_outlined, color: TandemTokens.color_link_direct),
                const SizedBox(width: TandemTokens.space_3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trash retention', style: TandemTokens.text_sm.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        '${widget.trashFileCount} files in .tandem-trash (${widget.trashSize}) • Kept for 30 days',
                        style: TandemTokens.text_xs.copyWith(color: TandemTokens.color_text.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
                TandemButton(
                  label: 'Recover files',
                  variant: TandemButtonVariant.secondary,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: TandemTokens.space_6),

          // Danger Zone
          Center(
            child: TandemButton(
              label: 'Stop syncing this folder',
              variant: TandemButtonVariant.danger,
              onPressed: _showStopSyncDialog,
            ),
          ),
        ],
      ),
    );
  }
}
