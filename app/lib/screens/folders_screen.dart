import 'package:flutter/material.dart';
import '../components/buttons.dart';
import '../components/empty_state.dart';
import '../components/folder_row.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// Screen S2: Folders View (Section 10.1).
class FoldersScreen extends StatelessWidget {
  final List<TandemFolder> folders;
  final VoidCallback onAddFolder;
  final Function(TandemFolder folder)? onSelectFolder;

  const FoldersScreen({
    Key? key,
    required this.folders,
    required this.onAddFolder,
    this.onSelectFolder,
  }) : super(key: key);

  FolderType _parseType(String t) {
    switch (t) {
      case 'sendonly':
        return FolderType.sendOnly;
      case 'receiveonly':
        return FolderType.receiveOnly;
      default:
        return FolderType.sendReceive;
    }
  }

  FolderSyncState _parseState(TandemFolder f) {
    if (f.paused) return FolderSyncState.paused;
    switch (f.state) {
      case 'syncing':
      case 'scanning':
        return FolderSyncState.syncing;
      case 'error':
        return FolderSyncState.error;
      case 'conflicts':
        return FolderSyncState.conflicts;
      default:
        return FolderSyncState.upToDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty) {
      return EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'No synced folders yet',
        description: TandemStrings.get('folders.empty'),
        actionLabel: 'Choose folder',
        onAction: onAddFolder,
      );
    }

    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: const Text('Folders'),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: TandemTokens.space_3),
            child: TandemButton(
              label: 'Choose folder',
              variant: TandemButtonVariant.primary,
              onPressed: onAddFolder,
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: folders.length,
        itemBuilder: (context, index) {
          final f = folders[index];
          return FolderRow(
            path: f.path,
            label: f.label.isNotEmpty ? f.label : f.path,
            type: _parseType(f.type),
            state: _parseState(f),
            formattedSize: formatBytes(f.totalBytes),
            deviceCount: f.sharedDevices.length + 1,
            onTap: () => onSelectFolder?.call(f),
          );
        },
      ),
    );
  }
}

Future<void> showAddFolderDialog({
  required BuildContext context,
  required List<TandemDevice> pairedDevices,
  required Future<void> Function(String path, String label, String type, List<String> shared) onSubmit,
}) async {
  final pathCtrl = TextEditingController();
  final labelCtrl = TextEditingController();
  String selectedType = 'sendreceive';
  final selectedDevices = <String>{};

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: TandemTokens.color_surface,
        title: const Text('Choose folder to sync'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: pathCtrl,
                  decoration: const InputDecoration(labelText: 'Folder path'),
                ),
                const SizedBox(height: TandemTokens.space_3),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Label (optional)'),
                ),
                const SizedBox(height: TandemTokens.space_3),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Folder type'),
                  items: const [
                    DropdownMenuItem(value: 'sendreceive', child: Text('Send and receive')),
                    DropdownMenuItem(value: 'sendonly', child: Text('Send only')),
                    DropdownMenuItem(value: 'receiveonly', child: Text('Receive only')),
                  ],
                  onChanged: (v) => setState(() => selectedType = v ?? 'sendreceive'),
                ),
                if (pairedDevices.isNotEmpty) ...[
                  const SizedBox(height: TandemTokens.space_3),
                  Text('Share with devices', style: TandemTokens.text_sm),
                  ...pairedDevices.map(
                    (d) => CheckboxListTile(
                      dense: true,
                      value: selectedDevices.contains(d.id),
                      title: Text(d.name),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selectedDevices.add(d.id);
                          } else {
                            selectedDevices.remove(d.id);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TandemButton(
            label: 'Cancel',
            variant: TandemButtonVariant.quiet,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TandemButton(
            label: 'Add folder',
            onPressed: () async {
              final p = pathCtrl.text.trim();
              if (p.isEmpty) return;
              await onSubmit(p, labelCtrl.text.trim(), selectedType, selectedDevices.toList());
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    ),
  );
}
