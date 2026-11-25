import 'package:flutter/material.dart';
import '../components/buttons.dart';
import '../components/device_row.dart';
import '../components/tandem_logo.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';
import 'activity_screen.dart';
import 'devices_screen.dart';
import 'first_run_screen.dart';
import 'folder_detail_screen.dart';
import 'folders_screen.dart';
import 'health_check_screen.dart';
import 'link_status_screen.dart';
import 'pairing_screen.dart';
import 'send_screen.dart';
import 'settings_screen.dart';

enum _DesktopRoute {
  folders,
  send,
  devices,
  activity,
  health,
  settings,
}

/// Responsive App Shell backed strictly by TandemController.
/// Desktop (>=1024px): persistent left route + live LinkLine peer rail + left-aligned <=960px workspace.
/// Mobile (<1024px): clean single-pane navigation with bottom tabs and >=48dp interactive hit areas.
class HomeShell extends StatefulWidget {
  final TandemController controller;

  const HomeShell({Key? key, required this.controller}) : super(key: key);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _mobileTabIndex = 0;
  _DesktopRoute _desktopRoute = _DesktopRoute.folders;
  String? _selectedDeviceId;
  String? _selectedFolderId;

  TandemController get _ctrl => widget.controller;

  void _openPairing() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PairingScreen(controller: _ctrl)),
    );
  }

  void _openHealth() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HealthCheckScreen(controller: _ctrl)),
    );
  }

  void _openAddFolder() {
    final paired = _ctrl.devices.where((d) => d.isPaired).toList();
    showAddFolderDialog(
      context: context,
      pairedDevices: paired,
      onSubmit: (path, label, type, shared) =>
          _ctrl.addFolder(path: path, label: label, type: type, sharedDevices: shared),
    );
  }

  Widget _railItem({
    required TandemTheme t,
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? t.linkDirect.withAlpha(24) : TandemTokens.color_transparent,
      child: InkWell(
        onTap: onTap,
        focusColor: t.linkDirect.withAlpha(32),
        hoverColor: t.text.withAlpha(12),
        child: Container(
          height: 40.0,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: active ? t.linkDirect : TandemTokens.color_transparent,
                width: 3.0,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: TandemTokens.space_4),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18.0,
                color: active ? t.linkDirect : t.mutedText,
              ),
              const SizedBox(width: TandemTokens.space_3),
              Text(
                label,
                style: t.bodyStyle.copyWith(
                  fontSize: 14.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? t.linkDirect : t.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopWorkspace(
    TandemTheme t,
    DaemonStatus? status,
    List<TandemDevice> devices,
    List<TandemDevice> pairedDevices,
    List<TandemFolder> folders,
    TandemDevice? selectedDevice,
    TandemFolder? selectedFolder,
  ) {
    if (selectedDevice != null) {
      return LinkStatusScreen(
        controller: _ctrl,
        device: selectedDevice,
        health: _ctrl.health,
        embedded: true,
        onClose: () => setState(() => _selectedDeviceId = null),
      );
    }
    if (selectedFolder != null) {
      return FolderDetailScreen(
        controller: _ctrl,
        folder: selectedFolder,
        embedded: true,
        onClose: () => setState(() => _selectedFolderId = null),
      );
    }
    switch (_desktopRoute) {
      case _DesktopRoute.folders:
        return FoldersScreen(
          folders: folders,
          health: _ctrl.health,
          embedded: true,
          onOpenHealth: () => setState(() {
            _selectedDeviceId = null;
            _selectedFolderId = null;
            _desktopRoute = _DesktopRoute.health;
          }),
          onAddFolder: _openAddFolder,
          onSelectFolder: (f) => setState(() {
            _selectedDeviceId = null;
            _selectedFolderId = f.id;
          }),
        );
      case _DesktopRoute.send:
        return SendScreen(
          pairedDevices: pairedDevices,
          sessions: _ctrl.sendSessions,
          embedded: true,
          onInitiateSend: (id, paths) =>
              _ctrl.sendFiles(targetDeviceId: id, filePaths: paths),
        );
      case _DesktopRoute.devices:
        return DevicesScreen(
          status: status,
          devices: devices,
          embedded: true,
          selectedDeviceId: _selectedDeviceId,
          onPairDevice: _openPairing,
          onSelectDevice: (d) => setState(() => _selectedDeviceId = d.id),
        );
      case _DesktopRoute.activity:
        return ActivityScreen(controller: _ctrl, embedded: true);
      case _DesktopRoute.health:
        return HealthCheckScreen(controller: _ctrl, embedded: true);
      case _DesktopRoute.settings:
        return SettingsScreen(controller: _ctrl, embedded: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final devices = _ctrl.devices;
    final pairedDevices = devices.where((d) => d.isPaired).toList();
    final folders = _ctrl.folders;
    final status = _ctrl.status;

    if (pairedDevices.isEmpty && folders.isEmpty) {
      return FirstRunScreen(
        deviceName: status?.myDeviceName ?? '',
        deviceId: status?.myDeviceId ?? '',
        onPairDevice: _openPairing,
        onOpenHealth: _openHealth,
      );
    }

    if (t.isDesktop) {
      TandemDevice? selectedDevice;
      if (_selectedDeviceId != null) {
        for (final d in devices) {
          if (d.id == _selectedDeviceId) {
            selectedDevice = d;
            break;
          }
        }
      }
      TandemFolder? selectedFolder;
      if (_selectedFolderId != null) {
        for (final f in folders) {
          if (f.id == _selectedFolderId) {
            selectedFolder = f;
            break;
          }
        }
      }

      return Scaffold(
        backgroundColor: t.ground,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 288.0,
              decoration: BoxDecoration(
                color: t.surface,
                border: Border(right: BorderSide(color: t.border, width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TandemTokens.space_4,
                      TandemTokens.space_5,
                      TandemTokens.space_4,
                      TandemTokens.space_3,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const TandemLogo(size: 26.0),
                            const SizedBox(width: TandemTokens.space_2),
                            Expanded(
                              child: Text('Tandem', style: t.pageTitleStyle),
                            ),
                          ],
                        ),
                        if (status != null) ...[
                          const SizedBox(height: 2.0),
                          Text(
                            status.myDeviceName,
                            style: t.captionStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Divider(height: 1.0, color: t.border),
                  const SizedBox(height: TandemTokens.space_2),
                  _railItem(
                    t: t,
                    icon: Icons.folder_outlined,
                    label: 'Folders',
                    active: selectedDevice == null &&
                        selectedFolder == null &&
                        _desktopRoute == _DesktopRoute.folders,
                    onTap: () => setState(() {
                      _selectedDeviceId = null;
                      _selectedFolderId = null;
                      _desktopRoute = _DesktopRoute.folders;
                    }),
                  ),
                  _railItem(
                    t: t,
                    icon: Icons.send_outlined,
                    label: 'Send',
                    active: selectedDevice == null &&
                        selectedFolder == null &&
                        _desktopRoute == _DesktopRoute.send,
                    onTap: () => setState(() {
                      _selectedDeviceId = null;
                      _selectedFolderId = null;
                      _desktopRoute = _DesktopRoute.send;
                    }),
                  ),
                  _railItem(
                    t: t,
                    icon: Icons.devices_outlined,
                    label: 'Devices',
                    active: selectedDevice == null &&
                        selectedFolder == null &&
                        _desktopRoute == _DesktopRoute.devices,
                    onTap: () => setState(() {
                      _selectedDeviceId = null;
                      _selectedFolderId = null;
                      _desktopRoute = _DesktopRoute.devices;
                    }),
                  ),
                  _railItem(
                    t: t,
                    icon: Icons.history,
                    label: 'Activity',
                    active: selectedDevice == null &&
                        selectedFolder == null &&
                        _desktopRoute == _DesktopRoute.activity,
                    onTap: () => setState(() {
                      _selectedDeviceId = null;
                      _selectedFolderId = null;
                      _desktopRoute = _DesktopRoute.activity;
                    }),
                  ),
                  _railItem(
                    t: t,
                    icon: Icons.health_and_safety_outlined,
                    label: 'Health Check',
                    active: selectedDevice == null &&
                        selectedFolder == null &&
                        _desktopRoute == _DesktopRoute.health,
                    onTap: () => setState(() {
                      _selectedDeviceId = null;
                      _selectedFolderId = null;
                      _desktopRoute = _DesktopRoute.health;
                    }),
                  ),
                  _railItem(
                    t: t,
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    active: selectedDevice == null &&
                        selectedFolder == null &&
                        _desktopRoute == _DesktopRoute.settings,
                    onTap: () => setState(() {
                      _selectedDeviceId = null;
                      _selectedFolderId = null;
                      _desktopRoute = _DesktopRoute.settings;
                    }),
                  ),
                  const SizedBox(height: TandemTokens.space_3),
                  Divider(height: 1.0, color: t.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TandemTokens.space_4,
                      TandemTokens.space_3,
                      TandemTokens.space_3,
                      TandemTokens.space_2,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Peers', style: t.captionStyle),
                        ),
                        TandemButton(
                          label: 'Pair',
                          variant: TandemButtonVariant.quiet,
                          onPressed: _openPairing,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: devices.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: TandemTokens.space_4,
                              vertical: TandemTokens.space_2,
                            ),
                            child: Text(
                              'No peers paired or detected on this subnet yet.',
                              style: t.captionStyle,
                            ),
                          )
                        : ListView.builder(
                            itemCount: devices.length,
                            itemBuilder: (ctx, i) {
                              final d = devices[i];
                              return DeviceRow(
                                deviceId: d.id,
                                name: d.name.isNotEmpty ? d.name : d.id,
                                selected: d.id == _selectedDeviceId,
                                linkState: parseLinkState(d.linkState),
                                syncState: !d.isPaired
                                    ? DeviceSyncState.offline
                                    : ((d.uploadRateBytesPerSec > 0 ||
                                            d.downloadRateBytesPerSec > 0)
                                        ? DeviceSyncState.syncing
                                        : DeviceSyncState.upToDate),
                                lastSeen: d.isPaired
                                    ? formatLastSeen(d.lastSeen, fallback: 'Paired')
                                    : 'Nearby (not paired)',
                                onTap: () => setState(() {
                                  _selectedFolderId = null;
                                  _selectedDeviceId = d.id;
                                }),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: _buildDesktopWorkspace(
                  t,
                  status,
                  devices,
                  pairedDevices,
                  folders,
                  selectedDevice,
                  selectedFolder,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.ground,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TandemLogo(size: 22.0),
            const SizedBox(width: TandemTokens.space_2),
            Text('Tandem', style: t.sectionTitleStyle),
          ],
        ),
        backgroundColor: t.surface,
        foregroundColor: t.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: t.border),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.health_and_safety_outlined),
            tooltip: 'System Health Check',
            onPressed: _openHealth,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SettingsScreen(controller: _ctrl)),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _mobileTabIndex,
        children: [
          FoldersScreen(
            folders: folders,
            health: _ctrl.health,
            embedded: true,
            onOpenHealth: _openHealth,
            onAddFolder: _openAddFolder,
            onSelectFolder: (f) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FolderDetailScreen(controller: _ctrl, folder: f),
                ),
              );
            },
          ),
          SendScreen(
            pairedDevices: pairedDevices,
            sessions: _ctrl.sendSessions,
            embedded: true,
            onInitiateSend: (id, paths) =>
                _ctrl.sendFiles(targetDeviceId: id, filePaths: paths),
          ),
          DevicesScreen(
            status: status,
            devices: devices,
            embedded: true,
            onPairDevice: _openPairing,
            onSelectDevice: (d) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LinkStatusScreen(
                    controller: _ctrl,
                    device: d,
                    health: _ctrl.health,
                  ),
                ),
              );
            },
          ),
          ActivityScreen(controller: _ctrl, embedded: true),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _mobileTabIndex,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: t.surface,
          selectedItemColor: t.linkDirect,
          unselectedItemColor: t.mutedText,
          onTap: (index) => setState(() => _mobileTabIndex = index),
          items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Folders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.send_outlined),
            activeIcon: Icon(Icons.send),
            label: 'Send',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.devices_outlined),
            activeIcon: Icon(Icons.devices),
            label: 'Devices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            activeIcon: Icon(Icons.history),
            label: 'Activity',
          ),
        ],
        ),
      ),
    );
  }
}
