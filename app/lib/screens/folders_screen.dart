import 'package:flutter/material.dart';
import '../components/banner.dart';
import '../components/buttons.dart';
import '../components/empty_state.dart';
import '../components/folder_row.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// Screen S2: Folders View (Section 10.1).
/// Dense table of synchronized folders backed strictly by tandemd.
class FoldersScreen extends StatelessWidget {
  final List<TandemFolder> folders;
  final VoidCallback onAddFolder;
  final Function(TandemFolder folder)? onSelectFolder;
  final SystemHealth? health;
  final VoidCallback? onOpenHealth;
  final bool embedded;

  const FoldersScreen({
    Key? key,
    required this.folders,
    required this.onAddFolder,
    this.onSelectFolder,
    this.health,
    this.onOpenHealth,
    this.embedded = false,
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

  String? _healthBannerMessage() {
    final h = health;
    if (h == null) return null;
    if (!h.engineReady) {
      return 'Sync engine is not ready. Open Health Check for details.';
    }
    if (!h.storageOk) {
      return 'Storage check reported low free space or permissions error.';
    }
    if (h.firewallState == 'blocked') {
      return h.firewallRemediation.isNotEmpty
          ? h.firewallRemediation
          : 'Host firewall may block incoming sync connections.';
    }
    if (!h.syncPortOpen || !h.discoveryWorks) {
      return 'Local discovery or sync port is unavailable. Nearby devices may not appear.';
    }
    if (h.inotifyExhausted) {
      return 'File watch limit reached; folders fall back to periodic scans.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final healthWarning = _healthBannerMessage();

    final content = WorkspacePane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Folders', style: t.pageTitleStyle),
              ),
              TandemButton(
                label: 'Choose folder',
                variant: TandemButtonVariant.primary,
                onPressed: onAddFolder,
              ),
            ],
          ),
          if (healthWarning != null) ...[
            const SizedBox(height: TandemTokens.space_3),
            BannerNotification(
              variant: (health != null && (!health!.storageOk || !health!.engineReady))
                  ? BannerVariant.error
                  : BannerVariant.warning,
              message: healthWarning,
              actionLabel: onOpenHealth != null ? 'Health Check' : null,
              onAction: onOpenHealth,
            ),
          ],
          const SizedBox(height: TandemTokens.space_4),
          if (folders.isEmpty)
            EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No synced folders yet',
              description: TandemStrings.get('folders.empty'),
              actionLabel: 'Choose folder',
              onAction: onAddFolder,
            )
          else ...[
            if (t.isTabletOrLarger) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TandemTokens.space_4,
                  vertical: TandemTokens.space_2,
                ),
                decoration: BoxDecoration(
                  color: t.ground,
                  border: Border(
                    top: BorderSide(color: t.border, width: 0.5),
                    bottom: BorderSide(color: t.border, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 32.0),
                    Expanded(
                      flex: 4,
                      child: Text('Folder', style: t.captionStyle),
                    ),
                    const SizedBox(width: TandemTokens.space_3),
                    SizedBox(
                      width: 118.0,
                      child: Text('Mode', style: t.captionStyle),
                    ),
                    SizedBox(
                      width: 88.0,
                      child: Text(
                        'Size',
                        textAlign: TextAlign.right,
                        style: t.captionStyle,
                      ),
                    ),
                    SizedBox(
                      width: 86.0,
                      child: Text(
                        'Peers',
                        textAlign: TextAlign.right,
                        style: t.captionStyle,
                      ),
                    ),
                    const SizedBox(width: TandemTokens.space_3),
                    SizedBox(
                      width: 90.0,
                      child: Text(
                        'State',
                        textAlign: TextAlign.right,
                        style: t.captionStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Divider(height: 1.0, color: t.border),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
          ],
        ],
      ),
    );

    if (embedded) {
      return SingleChildScrollView(child: content);
    }

    return Scaffold(
      backgroundColor: t.ground,
      body: SingleChildScrollView(child: content),
    );
  }
}

Future<void> showAddFolderDialog({
  required BuildContext context,
  required List<TandemDevice> pairedDevices,
  required Future<void> Function(
    String path,
    String? label,
    String type,
    List<String> sharedDevices,
  ) onSubmit,
}) async {
  final pathCtrl = TextEditingController();
  final labelCtrl = TextEditingController();
  String folderType = 'sendreceive';
  final selectedDevices = <String>{};
  String? errorText;
  bool submitting = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final t = TandemTheme.of(ctx);
          return AlertDialog(
            backgroundColor: t.surface,
            title: Text('Choose folder to sync', style: t.sectionTitleStyle),
            content: SizedBox(
              width: 440.0,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: pathCtrl,
                      style: t.bodyStyle,
                      decoration: const InputDecoration(
                        labelText: 'Folder path',
                        hintText: '/path/to/folder',
                      ),
                    ),
                    const SizedBox(height: TandemTokens.space_3),
                    TextField(
                      controller: labelCtrl,
                      style: t.bodyStyle,
                      decoration: const InputDecoration(
                        labelText: 'Label (optional)',
                      ),
                    ),
                    const SizedBox(height: TandemTokens.space_3),
                    DropdownButtonFormField<String>(
                      value: folderType,
                      dropdownColor: t.surface,
                      style: t.bodyStyle,
                      decoration: const InputDecoration(labelText: 'Sync mode'),
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
                      onChanged: (v) {
                        if (v != null) setState(() => folderType = v);
                      },
                    ),
                    if (pairedDevices.isNotEmpty) ...[
                      const SizedBox(height: TandemTokens.space_4),
                      Text('Share with devices', style: t.captionStyle),
                      for (final dev in pairedDevices)
                        CheckboxListTile(
                          dense: true,
                          value: selectedDevices.contains(dev.id),
                          title: Text(dev.name, style: t.bodyStyle),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedDevices.add(dev.id);
                              } else {
                                selectedDevices.remove(dev.id);
                              }
                            });
                          },
                        ),
                    ],
                    if (errorText != null) ...[
                      const SizedBox(height: TandemTokens.space_2),
                      Text(
                        errorText!,
                        style: TandemTokens.text_sm.copyWith(color: t.danger),
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
                onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              ),
              TandemButton(
                label: 'Add folder',
                isLoading: submitting,
                onPressed: submitting
                    ? null
                    : () async {
                        final path = pathCtrl.text.trim();
                        if (path.isEmpty) {
                          setState(() => errorText = 'Enter an absolute folder path.');
                          return;
                        }
                        setState(() {
                          submitting = true;
                          errorText = null;
                        });
                        try {
                          await onSubmit(
                            path,
                            labelCtrl.text.trim().isEmpty
                                ? null
                                : labelCtrl.text.trim(),
                            folderType,
                            selectedDevices.toList(),
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } catch (e) {
                          setState(() {
                            submitting = false;
                            errorText = e.toString();
                          });
                        }
                      },
              ),
            ],
          );
        },
      );
    },
  );
  pathCtrl.dispose();
  labelCtrl.dispose();
}
