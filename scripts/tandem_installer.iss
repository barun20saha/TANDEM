; Tandem Windows Inno Setup Installer Script
#ifndef AppVersion
  #define AppVersion "0.3.0"
#endif
#ifndef CoreVersion
  #define CoreVersion "0.3.0"
#endif
#ifndef Arch
  #define Arch "amd64"
#endif
#ifndef StageDir
  #define StageDir "..\bin\stage"
#endif
#ifndef OutDir
  #define OutDir "..\bin"
#endif

[Setup]
AppId={{8D6B4F9E-3C1A-4E6B-9E27-2B1C5F84A901}
AppName=Tandem
AppVersion={#AppVersion}
AppVerName=Tandem {#AppVersion}
AppPublisher=Tandem Sync
AppPublisherURL=https://github.com/barun20saha/TANDEM
AppSupportURL=https://github.com/barun20saha/TANDEM/issues
DefaultDirName={autopf}\Tandem
DefaultGroupName=Tandem
LicenseFile={#StageDir}\LICENSE
OutputDir={#OutDir}
OutputBaseFilename=tandem-{#AppVersion}-windows-{#Arch}-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
VersionInfoVersion={#CoreVersion}.0
#if Arch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "firewall"; Description: "Configure Windows Defender Firewall rules (TCP/UDP 22000, UDP 21027)"; GroupDescription: "Network & Sync:"; Flags: checkedonce

[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
#if FileExists(StageDir + "\tandem.exe")
Name: "{group}\Tandem"; Filename: "{app}\tandem.exe"
Name: "{autodesktop}\Tandem"; Filename: "{app}\tandem.exe"; Tasks: desktopicon
#else
Name: "{group}\Tandem Daemon"; Filename: "{app}\tandemd.exe"
#endif
Name: "{group}\Uninstall Tandem"; Filename: "{uninstallexe}"

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install-firewall.ps1"""; Tasks: firewall; Flags: runhidden waituntilterminated; StatusMsg: "Configuring Windows Defender Firewall..."
#if FileExists(StageDir + "\tandem.exe")
Filename: "{app}\tandem.exe"; Description: "{cm:LaunchProgram,Tandem}"; Flags: nowait postinstall skipifsilent
#endif

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\uninstall-firewall.ps1"""; Flags: runhidden waituntilterminated
