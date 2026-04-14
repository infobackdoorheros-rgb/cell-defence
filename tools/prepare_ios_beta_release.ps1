param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$VersionName = "0.3.3",
    [string]$BuildNumber = "15",
    [string]$BundleIdentifier = "com.backdoorheroes.celldefensecoreimmunity",
    [string]$AuthBackendUrl = "https://cell-defense-auth-backend.onrender.com"
)

$ErrorActionPreference = "Stop"

function Clear-Directory {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Get-ChildItem -LiteralPath $Path -Force | Remove-Item -Force -Recurse
    } else {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Invoke-RobocopyMirror {
    param(
        [string]$Source,
        [string]$Destination,
        [string[]]$ExcludeDirs = @(),
        [string[]]$ExcludeFiles = @()
    )

    $arguments = @(
        $Source,
        $Destination,
        "/MIR",
        "/R:1",
        "/W:1",
        "/NFL",
        "/NDL",
        "/NJH",
        "/NJS",
        "/NC",
        "/NS"
    )

    if ($ExcludeDirs.Count -gt 0) {
        $arguments += "/XD"
        $arguments += $ExcludeDirs
    }

    if ($ExcludeFiles.Count -gt 0) {
        $arguments += "/XF"
        $arguments += $ExcludeFiles
    }

    & robocopy @arguments | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "Robocopy failed with exit code $LASTEXITCODE."
    }
}

$distRoot = Join-Path $ProjectRoot "dist\\ios"
$packageName = "cell-defense-core-immunity-ios-beta-$VersionName-source"
$stagingRoot = Join-Path $distRoot $packageName
$zipPath = Join-Path $distRoot "$packageName.zip"

$excludeDirs = @(
    (Join-Path $ProjectRoot ".git"),
    (Join-Path $ProjectRoot ".godot"),
    (Join-Path $ProjectRoot "android"),
    (Join-Path $ProjectRoot "backups"),
    (Join-Path $ProjectRoot "backend"),
    (Join-Path $ProjectRoot "dist"),
    (Join-Path $ProjectRoot "signing"),
    (Join-Path $ProjectRoot "tools\\android-cmdline-extract"),
    (Join-Path $ProjectRoot "tools\\jdk-17"),
    (Join-Path $ProjectRoot "backend\\node_modules")
)

$excludeFiles = @(
    "*.apk",
    "*.aab",
    "*.ipa",
    "*.xcarchive",
    "*.zip"
)

$null = New-Item -ItemType Directory -Path $distRoot -Force
Clear-Directory -Path $stagingRoot
Invoke-RobocopyMirror -Source $ProjectRoot -Destination $stagingRoot -ExcludeDirs $excludeDirs -ExcludeFiles $excludeFiles

$removeDirsAfterCopy = @(
    "android",
    "backend",
    "backups",
    "dist",
    "signing",
    "tools\\android-cmdline-extract",
    "tools\\jdk-17"
)

foreach ($relativeDir in $removeDirsAfterCopy) {
    $target = Join-Path $stagingRoot $relativeDir
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Force -Recurse
    }
}

$removeFilesAfterCopy = @(
    "tools\\android-commandlinetools.zip",
    "tools\\microsoft-jdk-17.zip"
)

foreach ($relativeFile in $removeFilesAfterCopy) {
    $target = Join-Path $stagingRoot $relativeFile
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Force
    }
}

$manifestPath = Join-Path $stagingRoot "IOS_BETA_BUILD_INFO.txt"
$manifest = @"
Cell Defense: Core Immunity
iOS beta source package

Version: $VersionName
Build: $BuildNumber
Bundle identifier: $BundleIdentifier
Auth backend: $AuthBackendUrl
Orientation: portrait
Godot target: 4.5.1

Notes:
- Export the iOS project from macOS with Godot export templates installed.
- Open the exported Xcode project, configure Signing & Capabilities, archive and upload to TestFlight.
- The project includes the current BackDoor Heroes intro, portrait HUD, FTUE and account center flow.
"@
Set-Content -LiteralPath $manifestPath -Value $manifest -Encoding UTF8

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $stagingRoot,
    $zipPath,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false
)

Write-Host "iOS beta source package created:"
Write-Host "  Folder: $stagingRoot"
Write-Host "  Zip:    $zipPath"
