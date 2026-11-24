import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../components/folder_row.dart';
import '../components/empty_state.dart';
import '../components/buttons.dart';

/// Screen S2: Folders View (Section 10.1).
/// Lists synced folders using dense FolderRow items. First thing on screen is user's folders.
class FoldersScreen extends StatelessWidget {
  final List<Map<String, dynamic>> folders;
  final VoidCallback onAddFolder;
  final Function(String folderId)? onSelectFolder;

  const FoldersScreen({
    Key? key,
    required this.folders,
    required this.onAddFolder,
    this.onSelectFolder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty) {
      return EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'No synced folders yet',
        description: 'Choose a folder to keep the same on all your devices.',
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
              label: 'Add folder',
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
            path: f['path'] ?? '',
            label: f['label'] ?? f['path'] ?? '',
            formattedSize: f['formattedSize'] ?? '0 B',
            deviceCount: (f['sharedDevices'] as List?)?.length ?? 1,
            onTap: () => onSelectFolder?.call(f['id'] ?? ''),
          );
        },
      ),
    );
  }
}
