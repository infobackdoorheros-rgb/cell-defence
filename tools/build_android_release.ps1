param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [Parameter(Mandatory = $true)][string]$KeystoreFile,
    [Parameter(Mandatory = $true)][string]$KeystorePassword,
    [Parameter(Mandatory = $true)][string]$KeyAlias,
    [string]$PackageName = "com.backdoorheroes.celldefensecoreimmunity",
    [string]$VersionName = "0.3.3",
    [int]$VersionCode = 15,
    [string[]]$EnabledAbis = @("arm64-v8a"),
    [switch]$SkipAab
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

function Mirror-Directory {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        return
    }

    $null = New-Item -ItemType Directory -Path $Destination -Force
    & robocopy $Source $Destination /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NC /NS | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "Robocopy failed while mirroring '$Source' to '$Destination' with exit code $LASTEXITCODE."
    }
}

function Copy-IfExists {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (Test-Path -LiteralPath $Source) {
        $parent = Split-Path -Parent $Destination
        if ($parent) {
            $null = New-Item -ItemType Directory -Path $parent -Force
        }
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
}

$gradleRoot = Join-Path $ProjectRoot "android\\build"
$assetsRoot = Join-Path $gradleRoot "assets"
$assetPackRoot = Join-Path $gradleRoot "assetPackInstallTime\\src\\main\\assets"
$distRoot = Join-Path $ProjectRoot "dist\\android"

$runtimeDirs = @(
    ".godot",
    "addons",
    "data",
    "scenes",
    "scripts"
)

$runtimeFiles = @(
    "project.godot",
    "export_presets.cfg",
    "BackDoorHerosLogo.png",
    "BackDoorHerosLogo.png.import",
    "icon.svg",
    "icon.svg.import",
    "music.mp3",
    "music.mp3.import"
)

function Sync-RuntimeAssets {
    param(
        [bool]$ToBaseAssets,
        [bool]$ToAssetPack
    )

    Clear-Directory -Path $assetsRoot
    Clear-Directory -Path $assetPackRoot

    $targets = @()
    if ($ToBaseAssets) {
        $targets += $assetsRoot
    }
    if ($ToAssetPack) {
        $targets += $assetPackRoot
    }

    foreach ($target in $targets) {
        foreach ($dir in $runtimeDirs) {
            Mirror-Directory -Source (Join-Path $ProjectRoot $dir) -Destination (Join-Path $target $dir)
        }

        foreach ($file in $runtimeFiles) {
            Copy-IfExists -Source (Join-Path $ProjectRoot $file) -Destination (Join-Path $target $file)
        }
    }

    Set-Content -LiteralPath (Join-Path $assetPackRoot ".gdkeep") -Value "." -NoNewline
}

function Sync-PlayGamesConfig {
    $configPath = Join-Path $ProjectRoot "data\\config\\auth_backend.json"
    $gameId = "0"

    if (Test-Path -LiteralPath $configPath) {
        try {
            $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
            $candidate = [string]$config.play_games_android_game_id
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                $gameId = $candidate.Trim()
            }
        } catch {
            Write-Warning "Unable to parse auth backend config for Play Games Game ID. Using fallback 0."
        }
    }

    $valuesDir = Join-Path $gradleRoot "res\\values"
    $null = New-Item -ItemType Directory -Path $valuesDir -Force
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string translatable="false" name="game_services_project_id">$gameId</string>
</resources>
"@
    Set-Content -LiteralPath (Join-Path $valuesDir "strings.xml") -Value $xml -Encoding UTF8
}

if (-not $env:JAVA_HOME) {
    $bundledJdk = Join-Path $ProjectRoot "tools\\jdk-17\\jdk-17.0.18+8"
    if (Test-Path -LiteralPath $bundledJdk) {
        $env:JAVA_HOME = $bundledJdk
        $env:Path = "$($env:JAVA_HOME)\\bin;$($env:Path)"
    }
}

$gradleArgs = @(
    "-Pexport_package_name=$PackageName",
    "-Pexport_version_code=$VersionCode",
    "-Pexport_version_name=$VersionName",
    "-Pexport_enabled_abis=$($EnabledAbis -join ',')",
    "-Paddons_directory=$((Join-Path $ProjectRoot 'addons'))",
    "-Pperform_signing=true",
    "-Pperform_zipalign=true",
    "-Prelease_keystore_file=$KeystoreFile",
    "-Prelease_keystore_password=$KeystorePassword",
    "-Prelease_keystore_alias=$KeyAlias",
    "-Prelease_key_password=$KeystorePassword"
)

$null = New-Item -ItemType Directory -Path $distRoot -Force
$apkVersioned = Join-Path $distRoot "cell-defense-core-immunity-release-$VersionName.apk"
$apkLatest = Join-Path $distRoot "cell-defense-core-immunity-release.apk"
$aabVersioned = Join-Path $distRoot "cell-defense-core-immunity-release-$VersionName.aab"
$aabLatest = Join-Path $distRoot "cell-defense-core-immunity-release.aab"

Push-Location $gradleRoot
try {
    Sync-PlayGamesConfig
    Sync-RuntimeAssets -ToBaseAssets $true -ToAssetPack $false
    & .\gradlew.bat clean @gradleArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle clean failed with exit code $LASTEXITCODE."
    }

    & .\gradlew.bat assembleStandardRelease @gradleArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle assembleStandardRelease failed with exit code $LASTEXITCODE."
    }

    $apkSource = Join-Path $gradleRoot "build\\outputs\\apk\\standard\\release\\android_release.apk"
    Copy-Item -LiteralPath $apkSource -Destination $apkVersioned -Force
    Copy-Item -LiteralPath $apkSource -Destination $apkLatest -Force

    if (-not $SkipAab) {
        Sync-RuntimeAssets -ToBaseAssets $false -ToAssetPack $true
        & .\gradlew.bat clean @gradleArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Gradle clean before bundle failed with exit code $LASTEXITCODE."
        }

        & .\gradlew.bat bundleStandardRelease @gradleArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Gradle bundleStandardRelease failed with exit code $LASTEXITCODE."
        }

        $aabSource = Join-Path $gradleRoot "build\\outputs\\bundle\\standardRelease\\build-standard-release.aab"
        Copy-Item -LiteralPath $aabSource -Destination $aabVersioned -Force
        Copy-Item -LiteralPath $aabSource -Destination $aabLatest -Force
    }
} finally {
    Pop-Location
}

Write-Host "Android release build completed for version $VersionName ($VersionCode)."
