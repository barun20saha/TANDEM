import 'package:flutter/material.dart';
import '../components/banner.dart';
import '../components/buttons.dart';
import '../components/confirm_dialog.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// Screen S3: Folder Detail (Section 10.1).
/// Backed by real tandemd folder status, errors, pause/resume, mode, and .tandem-trash.
class FolderDetailScreen extends StatefulWidget {
  final TandemController controller;
  final TandemFolder folder;

  const FolderDetailScreen({
    Key? key,
    required this.controller,
    required this.folder,
  }) : super(key: key);

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  late bool _paused;
  late String _syncMode;
  bool _loadingDetails = true;
  bool _busy = false;
  String? _errorText;
  List<FolderErrorItem> _errors = const [];
  List<TrashItem> _trashItems = const [];

  @override
  void initState() {
    super.initState();
    _paused = widget.folder.paused;
    _syncMode = widget.folder.type;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final client = widget.controller.client;
    if (client == null) {
      if (mounted) {
        setState(() {
          _loadingDetails = false;
          _errorText = 'Daemon is not connected.';
        });
      }
      return;
    }
    setState(() {
      _loadingDetails = true;
      _errorText = null;
    });
    try {
      final results = await Future.wait([
        client.getFolderErrors(widget.folder.id),
        client.getFolderTrash(widget.folder.id),
      ]);
      if (!mounted) return;
      setState(() {
        _errors = results[0] as List<FolderErrorItem>;
        _trashItems = results[1] as List<TrashItem>;
        _loadingDetails = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDetails = false;
        _errorText = e.toString();
      });
    }
  }

  Future<void> _togglePaused() async {
    final next = !_paused;
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      await widget.controller.updateFolder(widget.folder.id, paused: next);
      if (!mounted) return;
      setState(() {
        _paused = next;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorText = e.toString();
      });
    }
  }

  Future<void> _changeMode(String mode) async {
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      await widget.controller.updateFolder(widget.folder.id, type: mode);
      if (!mounted) return;
      setState(() {
        _syncMode = mode;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorText = e.toString();
      });
    }
  }

  Future<void> _restoreItem(TrashItem item) async {
    final client = widget.controller.client;
    if (client == null) return;
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      await client.restoreTrashItem(widget.folder.id, item.trashId);
      await widget.controller.refreshAll();
      await _loadDetails();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _confirmStopSyncing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Stop syncing this folder?',
        body: TandemStrings.get('confirm.stop_syncing'),
        confirmLabel: 'Stop syncing',
        cancelLabel: 'Cancel',
        isDestructive: true,
        onCancel: () => Navigator.of(ctx).pop(false),
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      await widget.controller.removeFolder(widget.folder.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorText = e.toString();
        });
      }
    }
  }

  Widget _buildModeOption(String value, String title, String subtitle) {
    return RadioListTile<String>(
      value: value,
      groupValue: _syncMode,
      activeColor: TandemTokens.color_link_direct,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: TandemTokens.text_md),
      subtitle: Text(
        subtitle,
        style: TandemTokens.text_sm.copyWith(
          color: TandemTokens.color_text.withAlpha(153),
        ),
      ),
      onChanged: _busy
          ? null
          : (val) {
              if (val != null && val != _syncMode) {
                _changeMode(val);
              }
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final folder = widget.folder;
    final displayTitle = folder.label.isNotEmpty ? folder.label : folder.id;
    final totalTrashBytes =
        _trashItems.fold<int>(0, (sum, item) => sum + item.sizeBytes);

    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: Text(displayTitle),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh folder',
            onPressed: _busy ? null : _loadDetails,
          ),
          Padding(
            padding: const EdgeInsets.only(right: TandemTokens.space_3),
            child: TandemButton(
              label: _paused ? 'Resume' : 'Pause',
              variant: TandemButtonVariant.secondary,
              isLoading: _busy,
              onPressed: _busy ? null : _togglePaused,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(TandemTokens.space_4),
        children: [
          if (_errorText != null) ...[
            BannerNotification(
              variant: BannerVariant.error,
              message: _errorText!,
            ),
            const SizedBox(height: TandemTokens.space_3),
          ],
          if (_paused) ...[
            const BannerNotification(
              variant: BannerVariant.info,
              message:
                  'Syncing paused: changes will stay queued until you resume this folder.',
            ),
            const SizedBox(height: TandemTokens.space_3),
          ],
          for (final err in _errors) ...[
            BannerNotification(
              variant: BannerVariant.warning,
              message: err.path.isNotEmpty
                  ? '${err.code}: ${err.path} (${err.message})'
                  : '${err.code}: ${err.message}',
            ),
            const SizedBox(height: TandemTokens.space_3),
          ],
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
                  folder.path,
                  style: TandemTokens.text_sm.copyWith(
                    color: TandemTokens.color_text.withAlpha(153),
                  ),
                ),
                const SizedBox(height: TandemTokens.space_2),
                Text(
                  '${folder.totalFiles} files • ${formatBytes(folder.totalBytes)} • State: ${_paused ? 'paused' : folder.state}',
                  style: TandemTokens.text_md,
                ),
                if (folder.needBytes > 0) ...[
                  const SizedBox(height: TandemTokens.space_2),
                  Text(
                    'Remaining to sync: ${formatBytes(folder.needBytes)}',
                    style: TandemTokens.text_sm,
                  ),
                ],
                const SizedBox(height: TandemTokens.space_3),
                Text(
                  'Shared with: ${folder.sharedDevices.isEmpty ? 'This device only' : folder.sharedDevices.join(', ')}',
                  style: TandemTokens.text_sm.copyWith(
                    color: TandemTokens.color_text.withAlpha(153),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TandemTokens.space_5),
          Text(
            'Sync mode',
            style: TandemTokens.text_md.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: TandemTokens.space_2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TandemTokens.space_4,
              vertical: TandemTokens.space_2,
            ),
            decoration: BoxDecoration(
              color: TandemTokens.color_surface,
              borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
              border: Border.all(color: TandemTokens.color_border, width: 0.5),
            ),
            child: Column(
              children: [
                _buildModeOption(
                  'sendreceive',
                  'Send and receive',
                  'Keep every paired copy identical both ways.',
                ),
                const Divider(height: 1.0, color: TandemTokens.color_border),
                _buildModeOption(
                  'sendonly',
                  'Send only',
                  'Push local changes out; keep local files untouched by peers.',
                ),
                const Divider(height: 1.0, color: TandemTokens.color_border),
                _buildModeOption(
                  'receiveonly',
                  'Receive only',
                  'Accept updates from peers without sending local edits back.',
                ),
              ],
            ),
          ),
          const SizedBox(height: TandemTokens.space_5),
          Text(
            'Trash (${_trashItems.length} files, ${formatBytes(totalTrashBytes)})',
            style: TandemTokens.text_md.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: TandemTokens.space_2),
          Container(
            padding: const EdgeInsets.all(TandemTokens.space_4),
            decoration: BoxDecoration(
              color: TandemTokens.color_surface,
              borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
              border: Border.all(color: TandemTokens.color_border, width: 0.5),
            ),
            child: _loadingDetails
                ? const Center(child: CircularProgressIndicator())
                : _trashItems.isEmpty
                    ? Text(
                        'No files in .tandem-trash for this folder.',
                        style: TandemTokens.text_sm.copyWith(
                          color: TandemTokens.color_text.withAlpha(153),
                        ),
                      )
                    : Column(
                        children: _trashItems.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: TandemTokens.space_2,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.originalPath,
                                        style: TandemTokens.text_md,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${formatBytes(item.sizeBytes)} • Deleted ${item.deletedAt}',
                                        style: TandemTokens.text_sm.copyWith(
                                          color:
                                              TandemTokens.color_text.withAlpha(153),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: TandemTokens.space_3),
                                TandemButton(
                                  label: 'Restore',
                                  variant: TandemButtonVariant.secondary,
                                  onPressed: _busy ? null : () => _restoreItem(item),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
          ),
          const SizedBox(height: TandemTokens.space_6),
          Align(
            alignment: Alignment.centerLeft,
            child: TandemButton(
              label: 'Stop syncing folder',
              variant: TandemButtonVariant.destructive,
              onPressed: _busy ? null : _confirmStopSyncing,
            ),
          ),
        ],
      ),
    );
  }
}
