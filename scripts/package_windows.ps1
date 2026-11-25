# Windows Distribution Packaging Script
Param(
    [string]$Version = "0.2.0",
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

$ZipPath = Join-Path $OutDir "tandem-$Version-windows-$Arch.zip"
if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
Compress-Archive -Path (Join-Path $StageDir "*") -DestinationPath $ZipPath -CompressionLevel Optimal
Write-Host "Created Windows package at $ZipPath"
