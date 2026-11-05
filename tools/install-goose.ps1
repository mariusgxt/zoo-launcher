# Installs the prebuilt Goose compiler for the current user on Windows and
# puts it on PATH. The release zip already carries gfx, ui and the standard
# library, so nothing has to be built. `goose build` still needs Visual
# Studio 2022 (or clang) for the C step; `goose file.goose` does not.
#
#   powershell -ExecutionPolicy Bypass -File tools\install-goose.ps1
param([string]$Version = "v2026.3")

$ErrorActionPreference = "Stop"
$name = "goose-$Version-windows-x64"
$url = "https://github.com/aardappel/goose/releases/download/$Version/$name.zip"
$root = Join-Path $env:LOCALAPPDATA "goose"
$zip = Join-Path $env:TEMP "$name.zip"

Write-Host "Downloading $url"
Invoke-WebRequest -Uri $url -OutFile $zip
New-Item -ItemType Directory -Force -Path $root | Out-Null
Expand-Archive -Path $zip -DestinationPath $root -Force
Remove-Item $zip

# The archive holds one folder named like the zip; that folder goes on PATH.
$bin = Join-Path $root $name
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ";") -notcontains $bin) {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$bin", "User")
    Write-Host "Added $bin to your PATH. Open a new terminal to use it."
}
$env:Path = "$env:Path;$bin"
& (Join-Path $bin "goose.exe") toolchain
