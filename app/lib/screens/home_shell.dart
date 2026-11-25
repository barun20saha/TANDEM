import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tokens.dart';
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

/// Responsive App Shell backed strictly by TandemController.
class HomeShell extends StatefulWidget {
  final TandemController controller;

  const HomeShell({Key? key, required this.controller}) : super(key: key);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  String? _selectedDeviceId;

  TandemController get _ctrl => widget.controller;

  void _openPairing() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PairingScreen(controller: _ctrl),
      ),
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

  @override
  Widget build(BuildContext context) {
    final devices = _ctrl.devices;
    final folders = _ctrl.folders;
    final status = _ctrl.status;

    if (devices.isEmpty && folders.isEmpty) {
      return FirstRunScreen(
        deviceName: status?.myDeviceName ?? '',
        deviceId: status?.myDeviceId ?? '',
        onPairDevice: _openPairing,
      );
    }

    final pairedDevices = devices.where((d) => d.isPaired).toList();
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;

    if (isDesktop) {
      TandemDevice? selectedDevice;
      if (_selectedDeviceId != null) {
        for (final d in devices) {
          if (d.id == _selectedDeviceId) {
            selectedDevice = d;
            break;
          }
        }
      }

      return Scaffold(
        backgroundColor: TandemTokens.color_ground,
        appBar: AppBar(
          title: const Text('Tandem'),
          backgroundColor: TandemTokens.color_surface,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.send_outlined),
              tooltip: 'Send',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SendScreen(
                      pairedDevices: pairedDevices,
                      sessions: _ctrl.sendSessions,
                      onInitiateSend: (id, paths) =>
                          _ctrl.sendFiles(targetDeviceId: id, filePaths: paths),
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.favorite_outline),
              tooltip: 'Health Check',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => HealthCheckScreen(controller: _ctrl)),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Activity',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ActivityScreen(controller: _ctrl)),
                );
              },
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
        body: Row(
          children: [
            SizedBox(
              width: 320.0,
              child: DevicesScreen(
                status: status,
                devices: devices,
                onPairDevice: _openPairing,
                onSelectDevice: (d) => setState(() => _selectedDeviceId = d.id),
              ),
            ),
            const VerticalDivider(width: 1.0, color: TandemTokens.color_border),
            Expanded(
              child: selectedDevice != null
                  ? LinkStatusScreen(
                      controller: _ctrl,
                      device: selectedDevice,
                      health: _ctrl.health,
                    )
                  : FoldersScreen(
                      folders: folders,
                      onAddFolder: _openAddFolder,
                      onSelectFolder: (f) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FolderDetailScreen(
                              controller: _ctrl,
                              folder: f,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: const Text('Tandem'),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            tooltip: 'System Health Check',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => HealthCheckScreen(controller: _ctrl)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Activity Log',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ActivityScreen(controller: _ctrl)),
              );
            },
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
        index: _currentIndex,
        children: [
          FoldersScreen(
            folders: folders,
            onAddFolder: _openAddFolder,
            onSelectFolder: (f) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FolderDetailScreen(
                    controller: _ctrl,
                    folder: f,
                  ),
                ),
              );
            },
          ),
          SendScreen(
            pairedDevices: pairedDevices,
            sessions: _ctrl.sendSessions,
            onInitiateSend: (id, paths) =>
                _ctrl.sendFiles(targetDeviceId: id, filePaths: paths),
          ),
          DevicesScreen(
            status: status,
            devices: devices,
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
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: TandemTokens.color_surface,
        selectedItemColor: TandemTokens.color_link_direct,
        unselectedItemColor: TandemTokens.color_text.withAlpha(153),
        onTap: (index) => setState(() => _currentIndex = index),
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
        ],
      ),
    );
  }
}
