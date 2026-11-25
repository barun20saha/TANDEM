class DaemonStatus {
  final String version;
  final String myDeviceId;
  final String myDeviceName;
  final String state;
  final bool hasInternet;
  final int activeTransfers;
  final int syncPort;
  final int discoveryPort;

  const DaemonStatus({
    required this.version,
    required this.myDeviceId,
    required this.myDeviceName,
    required this.state,
    required this.hasInternet,
    required this.activeTransfers,
    required this.syncPort,
    required this.discoveryPort,
  });

  factory DaemonStatus.fromJson(Map<String, dynamic> json) {
    return DaemonStatus(
      version: json['version']?.toString() ?? '',
      myDeviceId: json['myDeviceId']?.toString() ?? '',
      myDeviceName: json['myDeviceName']?.toString() ?? '',
      state: json['state']?.toString() ?? 'idle',
      hasInternet: json['hasInternet'] == true,
      activeTransfers: (json['activeTransfers'] as num?)?.toInt() ?? 0,
      syncPort: (json['syncPort'] as num?)?.toInt() ?? 22000,
      discoveryPort: (json['discoveryPort'] as num?)?.toInt() ?? 21027,
    );
  }
}

class SystemHealth {
  final bool engineReady;
  final bool syncPortOpen;
  final String firewallState;
  final String firewallRemediation;
  final String firewallCommand;
  final bool discoveryWorks;
  final bool storageOk;
  final bool inotifyExhausted;
  final bool batteryOptimized;

  const SystemHealth({
    required this.engineReady,
    required this.syncPortOpen,
    required this.firewallState,
    required this.firewallRemediation,
    required this.firewallCommand,
    required this.discoveryWorks,
    required this.storageOk,
    required this.inotifyExhausted,
    required this.batteryOptimized,
  });

  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    return SystemHealth(
      engineReady: json['engineReady'] != false,
      syncPortOpen: json['syncPortOpen'] != false,
      firewallState: json['firewallState']?.toString() ?? 'unknown',
      firewallRemediation: json['firewallRemediation']?.toString() ?? '',
      firewallCommand: json['firewallCommand']?.toString() ?? '',
      discoveryWorks: json['discoveryWorks'] == true,
      storageOk: json['storageOk'] != false,
      inotifyExhausted: json['inotifyExhausted'] == true,
      batteryOptimized: json['batteryOptimized'] == true,
    );
  }
}

class TandemDevice {
  final String id;
  final String name;
  final bool isPaired;
  final String linkState;
  final String lastSeen;
  final List<String> addresses;
  final int uploadRateBytesPerSec;
  final int downloadRateBytesPerSec;

  const TandemDevice({
    required this.id,
    required this.name,
    required this.isPaired,
    required this.linkState,
    required this.lastSeen,
    required this.addresses,
    required this.uploadRateBytesPerSec,
    required this.downloadRateBytesPerSec,
  });

  factory TandemDevice.fromJson(Map<String, dynamic> json) {
    return TandemDevice(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isPaired: json['isPaired'] == true,
      linkState: json['linkState']?.toString() ?? 'offline',
      lastSeen: json['lastSeen']?.toString() ?? '',
      addresses: (json['addresses'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      uploadRateBytesPerSec: (json['uploadRateBytesPerSec'] as num?)?.toInt() ?? 0,
      downloadRateBytesPerSec: (json['downloadRateBytesPerSec'] as num?)?.toInt() ?? 0,
    );
  }
}

class TandemFolder {
  final String id;
  final String label;
  final String path;
  final String type;
  final String state;
  final bool paused;
  final List<String> sharedDevices;
  final int totalBytes;
  final int totalFiles;
  final int needBytes;
  final int trashCount;

  const TandemFolder({
    required this.id,
    required this.label,
    required this.path,
    required this.type,
    required this.state,
    required this.paused,
    required this.sharedDevices,
    required this.totalBytes,
    required this.totalFiles,
    required this.needBytes,
    required this.trashCount,
  });

  factory TandemFolder.fromJson(Map<String, dynamic> json) {
    return TandemFolder(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      type: json['type']?.toString() ?? 'sendreceive',
      state: json['state']?.toString() ?? 'idle',
      paused: json['paused'] == true,
      sharedDevices: (json['sharedDevices'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      totalFiles: (json['totalFiles'] as num?)?.toInt() ?? 0,
      needBytes: (json['needBytes'] as num?)?.toInt() ?? 0,
      trashCount: (json['trashCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class FolderErrorItem {
  final String code;
  final String path;
  final String message;

  const FolderErrorItem({
    required this.code,
    required this.path,
    required this.message,
  });

  factory FolderErrorItem.fromJson(Map<String, dynamic> json) {
    return FolderErrorItem(
      code: json['code']?.toString() ?? 'folder_error',
      path: json['path']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

class TrashItem {
  final String trashId;
  final String originalPath;
  final String deletedAt;
  final int sizeBytes;

  const TrashItem({
    required this.trashId,
    required this.originalPath,
    required this.deletedAt,
    required this.sizeBytes,
  });

  factory TrashItem.fromJson(Map<String, dynamic> json) {
    return TrashItem(
      trashId: json['trashId']?.toString() ?? '',
      originalPath: json['originalPath']?.toString() ?? '',
      deletedAt: json['deletedAt']?.toString() ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class SendSession {
  final String sessionId;
  final String targetDeviceId;
  final String state;
  final int filesSent;
  final int totalFiles;
  final int bytesSent;
  final int totalBytes;
  final int speedBytesPerSec;
  final String interfaceUsed;

  const SendSession({
    required this.sessionId,
    required this.targetDeviceId,
    required this.state,
    required this.filesSent,
    required this.totalFiles,
    required this.bytesSent,
    required this.totalBytes,
    required this.speedBytesPerSec,
    required this.interfaceUsed,
  });

  double get progress => totalBytes > 0 ? (bytesSent / totalBytes).clamp(0.0, 1.0) : 0.0;

  factory SendSession.fromJson(Map<String, dynamic> json) {
    return SendSession(
      sessionId: json['sessionId']?.toString() ?? '',
      targetDeviceId: json['targetDeviceId']?.toString() ?? '',
      state: json['state']?.toString() ?? 'queued',
      filesSent: (json['filesSent'] as num?)?.toInt() ?? 0,
      totalFiles: (json['totalFiles'] as num?)?.toInt() ?? 0,
      bytesSent: (json['bytesSent'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      speedBytesPerSec: (json['speedBytesPerSec'] as num?)?.toInt() ?? 0,
      interfaceUsed: json['interfaceUsed']?.toString() ?? 'connecting',
    );
  }
}

class PairingPayload {
  final String deviceId;
  final String name;
  final String qrPayload;
  final String shortCode;

  const PairingPayload({
    required this.deviceId,
    required this.name,
    required this.qrPayload,
    required this.shortCode,
  });

  factory PairingPayload.fromJson(Map<String, dynamic> json) {
    return PairingPayload(
      deviceId: json['deviceId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      qrPayload: json['qrPayload']?.toString() ?? '',
      shortCode: json['shortCode']?.toString() ?? '',
    );
  }
}

class DaemonEvent {
  final String event;
  final Map<String, dynamic> raw;

  const DaemonEvent({required this.event, required this.raw});
}
