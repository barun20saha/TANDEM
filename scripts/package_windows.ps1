# Windows Installer Packaging Script (Section 4.3 & Phase 8)
Param(
    [string]$Version = "0.1.0"
)

$ErrorActionPreference = "Stop"

Write-Host "Packaging Tandem for Windows..."
$OutDir = "$PSScriptRoot\..\bin"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$ExePath = "$OutDir\tandemd.exe"
if (-not (Test-Path $ExePath)) {
    Write-Host "Cross-compiling tandemd.exe for windows/amd64..."
    Push-Location "$PSScriptRoot\..\core"
    $env:GOOS = "windows"
    $env:GOARCH = "amd64"
    go build -o $ExePath ./cmd/tandemd
    Pop-Location
}

Write-Host "Windows binary produced at $ExePath"
Write-Host "Installer rule: Installer adds inbound firewall rules for TCP/UDP 22000 and UDP 21027."
