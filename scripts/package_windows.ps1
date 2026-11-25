# Windows Distribution Packaging Script (.zip portable + Inno Setup .exe installer)
Param(
    [string]$Version = "0.2.3",
    [string]$Arch = "amd64",
    [string]$Channel = "stable",
    [string]$OutDir = "",
    [string]$FlutterBundleDir = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
if (-not $OutDir) {
    $OutDir = Join-Path $RepoRoot "bin"
}
if (Test-Path (Join-Path $RepoRoot "VERSION")) {
    $FileVersion = (Get-Content (Join-Path $RepoRoot "VERSION") -Raw).Trim()
    if ($FileVersion -and $PSBoundParameters.ContainsKey("Version") -eq $false) {
        $Version = $FileVersion
    }
}
$CoreVersion = ($Version -split "-")[0]

$CommitSha = "unknown"
try {
    $CommitSha = (git -C $RepoRoot rev-parse --short HEAD 2>$null).Trim()
} catch {}
$BuildDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$StageDir = Join-Path ([System.IO.Path]::GetTempPath()) "tandem-$Version-windows-$Arch"
if (Test-Path $StageDir) { Remove-Item -Recurse -Force $StageDir }
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null

$ExePath = Join-Path $StageDir "tandemd.exe"
$LdFlags = "-s -w -X main.version=$Version -X main.commit=$CommitSha -X main.buildDate=$BuildDate -X main.channel=$Channel"

Write-Host "Building tandemd.exe $Version for windows/$Arch..."
Push-Location (Join-Path $RepoRoot "core")
$env:CGO_ENABLED = "0"
$env:GOOS = "windows"
$env:GOARCH = $Arch
go build -trimpath -ldflags $LdFlags -o $ExePath ./cmd/tandemd
Pop-Location

if ($FlutterBundleDir -and (Test-Path $FlutterBundleDir)) {
    Write-Host "Copying Flutter Windows release bundle from $FlutterBundleDir..."
    Copy-Item -Path (Join-Path $FlutterBundleDir "*") -Destination $StageDir -Recurse -Force
}

Copy-Item (Join-Path $RepoRoot "README.md") -Destination $StageDir
Copy-Item (Join-Path $RepoRoot "LICENSE") -Destination $StageDir
Copy-Item (Join-Path $RepoRoot "THIRD_PARTY_NOTICES.md") -Destination $StageDir

$FirewallScript = @"
# Run as Administrator to open Tandem P2P ports in Windows Defender Firewall
New-NetFirewallRule -DisplayName "Tandem Sync (TCP 22000)" -Direction Inbound -Protocol TCP -LocalPort 22000 -Action Allow -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -DisplayName "Tandem Sync (UDP 22000)" -Direction Inbound -Protocol UDP -LocalPort 22000 -Action Allow -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -DisplayName "Tandem Local Discovery (UDP 21027)" -Direction Inbound -Protocol UDP -LocalPort 21027 -Action Allow -ErrorAction SilentlyContinue | Out-Null
Write-Host "Tandem Windows Firewall rules installed."
"@
Set-Content -Path (Join-Path $StageDir "install-firewall.ps1") -Value $FirewallScript -Encoding UTF8

# 1. Portable ZIP bundle
$ZipPath = Join-Path $OutDir "tandem-$Version-windows-$Arch.zip"
if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
Compress-Archive -Path (Join-Path $StageDir "*") -DestinationPath $ZipPath -CompressionLevel Optimal
Write-Host "Created Windows portable ZIP at $ZipPath"

# 2. Inno Setup .exe Installer (if ISCC.exe is installed)
$IsccCandidates = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)
$Iscc = $IsccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Iscc) {
    $Cmd = Get-Command iscc -ErrorAction SilentlyContinue
    if ($Cmd) { $Iscc = $Cmd.Source }
}

if ($Iscc) {
    $IssFile = Join-Path $PSScriptRoot "tandem_installer.iss"
    Write-Host "Building Windows .exe installer using $Iscc..."
    & $Iscc "/DAppVersion=$Version" "/DCoreVersion=$CoreVersion" "/DArch=$Arch" "/DStageDir=$StageDir" "/DOutDir=$OutDir" $IssFile
    $SetupExe = Join-Path $OutDir "tandem-$Version-windows-$Arch-setup.exe"
    if (Test-Path $SetupExe) {
        Write-Host "Created Windows installer at $SetupExe"
        # Optional Authenticode code signing if certificate secret is provided
        if ($env:WINDOWS_CERT_PFX_BASE64 -and $env:WINDOWS_CERT_PASSWORD) {
            $PfxPath = Join-Path ([System.IO.Path]::GetTempPath()) "tandem-codesign.pfx"
            [IO.File]::WriteAllBytes($PfxPath, [Convert]::FromBase64String($env:WINDOWS_CERT_PFX_BASE64))
            $SignTool = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1
            if ($SignTool) {
                & $SignTool.FullName sign /f $PfxPath /p $env:WINDOWS_CERT_PASSWORD /tr http://timestamp.digicert.com /td sha256 /fd sha256 $SetupExe
            }
            Remove-Item -Force $PfxPath -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host "Note: Inno Setup (ISCC.exe) not found; skipped .exe installer generation."
}
