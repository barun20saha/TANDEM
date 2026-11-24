import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'folders_screen.dart';
import 'folder_detail_screen.dart';
import 'send_screen.dart';
import 'devices_screen.dart';
import 'link_status_screen.dart';
import 'no_internet_helper_screen.dart';
import 'pairing_screen.dart';
import 'settings_screen.dart';
import 'health_check_screen.dart';
import 'activity_screen.dart';

/// Responsive App Shell adapting between Desktop (two panes) and Mobile (bottom navigation) per Section 10.2.
class HomeShell extends StatefulWidget {
  const HomeShell({Key? key}) : super(key: key);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  String? _selectedDeviceId;

  // Mock initial state for UI rendering
  final List<Map<String, dynamic>> _folders = [
    {
      'id': 'folder-1',
      'label': 'Work Documents',
      'path': '/home/barun/Documents/Work',
      'formattedSize': '1.4 GB',
      'sharedDevices': ['DEV-PHONE', 'DEV-DESKTOP'],
    },
    {
      'id': 'folder-2',
      'label': 'Camera Photos',
      'path': '/sdcard/DCIM/Camera',
      'formattedSize': '14.2 GB',
      'sharedDevices': ['DEV-DESKTOP'],
    },
  ];

  final List<Map<String, dynamic>> _devices = [
    {
      'id': 'THIS-DEVICE',
      'name': 'Barun’s Linux Laptop',
      'isThisDevice': true,
      'linkState': 'direct-local',
      'lastSeen': 'Active now',
    },
    {
      'id': 'DEV-PHONE',
      'name': 'Pixel 9 Pro (Local Wi-Fi)',
      'isThisDevice': false,
      'linkState': 'direct-local',
      'lastSeen': 'Just now',
    },
    {
      'id': 'DEV-DESKTOP',
      'name': 'Home Server (Internet)',
      'isThisDevice': false,
      'linkState': 'direct-internet',
      'lastSeen': '10m ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;

    if (isDesktop) {
      // Desktop Two-Pane Layout (Section 10.2)
      return Scaffold(
        backgroundColor: TandemTokens.color_ground,
        body: Row(
          children: [
            // Left Pane: Navigation & Device List (320px)
            SizedBox(
              width: 320.0,
              child: DevicesScreen(
                devices: _devices,
                onPairDevice: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NoInternetHelperScreen(),
                  ));
                },
                onSelectDevice: (id) {
                  setState(() => _selectedDeviceId = id);
                },
              ),
            ),
            const VerticalDivider(width: 1.0, color: TandemTokens.color_border),

            // Right Pane: Folders or Device Detail
            Expanded(
              child: _selectedDeviceId != null
                  ? LinkStatusScreen(
                      deviceName: 'Pixel 9 Pro',
                      deviceId: _selectedDeviceId!,
                    )
                  : FoldersScreen(
                      folders: _folders,
                      onAddFolder: () {},
                      onSelectFolder: (id) {
                        final f = _folders.firstWhere((x) => x['id'] == id, orElse: () => _folders.first);
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => FolderDetailScreen(
                            folderId: f['id'] as String,
                            folderLabel: f['label'] as String,
                            folderPath: f['path'] as String,
                          ),
                        ));
                      },
                    ),
            ),
          ],
        ),
      );
    }

    // Mobile Navigation Layout (Section 10.2)
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
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const HealthCheckScreen(),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Activity Log',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ActivityScreen(),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              ));
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          FoldersScreen(
            folders: _folders,
            onAddFolder: () {},
            onSelectFolder: (id) {
              final f = _folders.firstWhere((x) => x['id'] == id, orElse: () => _folders.first);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FolderDetailScreen(
                  folderId: f['id'] as String,
                  folderLabel: f['label'] as String,
                  folderPath: f['path'] as String,
                ),
              ));
            },
          ),
          SendScreen(
            selectedFiles: const ['/tmp/document.pdf'],
            activeTransfers: const [
              {
                'fileName': 'document.pdf',
                'progress': 0.72,
                'speedText': '21.4 MB/s',
                'timeLeftText': '2s left',
                'interface': 'Direct Wi-Fi',
              }
            ],
            onPickFiles: () {},
          ),
          DevicesScreen(
            devices: _devices,
            onPairDevice: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PairingScreen(),
              ));
            },
            onSelectDevice: (id) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LinkStatusScreen(
                  deviceName: 'Companion Device',
                  deviceId: id,
                ),
              ));
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: TandemTokens.color_surface,
        selectedItemColor: TandemTokens.color_link_direct,
        unselectedItemColor: TandemTokens.color_text.withOpacity(0.6),
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
