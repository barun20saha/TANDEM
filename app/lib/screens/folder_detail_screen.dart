import 'package:flutter/material.dart';
import '../components/banner.dart';
import '../components/buttons.dart';
import '../components/confirm_dialog.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// Screen S3: Folder Detail (Section 10.1).
/// Backed by real tandemd folder status, errors, pause/resume, mode, and .tandem-trash.
class FolderDetailScreen extends StatefulWidget {
  final TandemController controller;
  final TandemFolder folder;
  final bool embedded;
  final VoidCallback? onClose;

  const FolderDetailScreen({
    Key? key,
    required this.controller,
    required this.folder,
    this.embedded = false,
    this.onClose,
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
        cancelLabel: 'Keep syncing',
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
      if (mounted) {
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorText = e.toString();
        });
      }
    }
  }

  Widget _kvRow(TandemTheme t, String label, String value, {bool mono = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TandemTokens.space_4,
        vertical: TandemTokens.space_3,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140.0,
            child: Text(label, style: t.secondaryStyle),
          ),
          Expanded(
            child: Text(
              value,
              style: mono ? t.monoStyle : t.tabularBodyStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(
    TandemTheme t,
    String value,
    String title,
    String subtitle,
  ) {
    return Material(
      color: t.surface,
      child: RadioListTile<String>(
        value: value,
        groupValue: _syncMode,
        activeColor: t.linkDirect,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TandemTokens.space_3,
        ),
        title: Text(title, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: t.secondaryStyle),
        onChanged: _busy
            ? null
            : (val) {
                if (val != null && val != _syncMode) {
                  _changeMode(val);
                }
              },
      ),
    );
  }

  String _formatFolderError(FolderErrorItem err) {
    final target = err.path.isNotEmpty ? ' (${err.path})' : '';
    switch (err.code) {
      case 'err.disk_full':
        return 'Not enough free disk space$target. ${err.message}';
      case 'err.inotify_limit':
        return 'File watcher limit reached$target. ${err.message}';
      case 'conflict.case':
        return 'Case-only filename collision$target. ${err.message}';
      case 'conflict.reserved':
        return 'Windows reserved filename$target. ${err.message}';
      default:
        return err.path.isNotEmpty ? '${err.message}$target' : err.message;
    }
  }

  String _resolvePeerNames(List<String> ids) {
    if (ids.isEmpty) return 'This device only';
    final devices = widget.controller.devices;
    return ids.map((id) {
      for (final d in devices) {
        if (d.id == id && d.name.isNotEmpty) {
          return d.name;
        }
      }
      return id;
    }).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final folder = widget.folder;
    final displayTitle = folder.label.isNotEmpty ? folder.label : folder.id;
    final totalTrashBytes =
        _trashItems.fold<int>(0, (sum, item) => sum + item.sizeBytes);
    final sharedLabel = _resolvePeerNames(folder.sharedDevices);

    final bodyContent = SingleChildScrollView(
      child: WorkspacePane(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.embedded) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayTitle, style: t.pageTitleStyle),
                        const SizedBox(height: 2.0),
                        Text(
                          folder.path,
                          style: t.monoStyle.copyWith(fontSize: 12.0, color: t.mutedText),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh folder',
                    onPressed: _busy ? null : _loadDetails,
                  ),
                  const SizedBox(width: TandemTokens.space_2),
                  TandemButton(
                    label: _paused ? 'Resume' : 'Pause',
                    variant: TandemButtonVariant.secondary,
                    isLoading: _busy,
                    onPressed: _busy ? null : _togglePaused,
                  ),
                  if (widget.onClose != null) ...[
                    const SizedBox(width: TandemTokens.space_2),
                    TandemButton(
                      label: 'Back',
                      variant: TandemButtonVariant.quiet,
                      onPressed: widget.onClose,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: TandemTokens.space_4),
            ],
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
                    'Syncing paused. Changes remain queued locally until resumed.',
              ),
              const SizedBox(height: TandemTokens.space_3),
            ],
            for (final err in _errors) ...[
              BannerNotification(
                variant: BannerVariant.warning,
                message: _formatFolderError(err),
              ),
              const SizedBox(height: TandemTokens.space_3),
            ],
            Text('Summary', style: t.sectionTitleStyle),
            const SizedBox(height: TandemTokens.space_2),
            Divider(height: 1.0, color: t.border),
            _kvRow(t, 'Path', folder.path, mono: true),
            _kvRow(t, 'Files', '${folder.totalFiles}'),
            _kvRow(t, 'Total size', formatBytes(folder.totalBytes)),
            _kvRow(t, 'State', _paused ? 'paused' : folder.state),
            if (folder.needBytes > 0)
              _kvRow(t, 'Remaining', formatBytes(folder.needBytes)),
            _kvRow(
              t,
              'Shared with',
              sharedLabel,
              mono: folder.sharedDevices.isNotEmpty &&
                  sharedLabel == folder.sharedDevices.join(', '),
            ),
            const SizedBox(height: TandemTokens.space_5),
            Text('Sync mode', style: t.sectionTitleStyle),
            const SizedBox(height: TandemTokens.space_2),
            Divider(height: 1.0, color: t.border),
            _buildModeOption(
              t,
              'sendreceive',
              'Send and receive',
              'Keep every paired copy identical both ways.',
            ),
            Divider(height: 1.0, color: t.border),
            _buildModeOption(
              t,
              'sendonly',
              'Send only',
              'Push local changes out; keep local files untouched by peers.',
            ),
            Divider(height: 1.0, color: t.border),
            _buildModeOption(
              t,
              'receiveonly',
              'Receive only',
              'Accept updates from peers without sending local edits back.',
            ),
            Divider(height: 1.0, color: t.border),
            const SizedBox(height: TandemTokens.space_5),
            Row(
              children: [
                Expanded(
                  child: Text('Deleted files (.tandem-trash)', style: t.sectionTitleStyle),
                ),
                Text(
                  '${_trashItems.length} ${_trashItems.length == 1 ? 'file' : 'files'} (${formatBytes(totalTrashBytes)})',
                  style: t.secondaryStyle,
                ),
              ],
            ),
            const SizedBox(height: TandemTokens.space_2),
            Divider(height: 1.0, color: t.border),
            if (_loadingDetails)
              Padding(
                padding: const EdgeInsets.all(TandemTokens.space_4),
                child: CircularProgressIndicator(color: t.linkDirect),
              )
            else if (_trashItems.isEmpty)
              Container(
                width: double.infinity,
                color: t.surface,
                padding: const EdgeInsets.all(TandemTokens.space_4),
                child: Text(
                  'No files in .tandem-trash for this folder.',
                  style: t.secondaryStyle,
                ),
              )
            else
              Column(
                children: _trashItems.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TandemTokens.space_4,
                      vertical: TandemTokens.space_3,
                    ),
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border(
                        bottom: BorderSide(color: t.border, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.originalPath,
                                style: t.bodyStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2.0),
                              Text(
                                '${formatBytes(item.sizeBytes)} deleted ${item.deletedAt}',
                                style: t.captionStyle,
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
            Divider(height: 1.0, color: t.border),
            const SizedBox(height: TandemTokens.space_6),
            TandemButton(
              label: 'Stop syncing folder',
              variant: TandemButtonVariant.destructive,
              onPressed: _busy ? null : _confirmStopSyncing,
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: t.ground,
      appBar: AppBar(
        title: Text(displayTitle, style: t.sectionTitleStyle),
        backgroundColor: t.surface,
        foregroundColor: t.text,
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
      body: bodyContent,
    );
  }
}
