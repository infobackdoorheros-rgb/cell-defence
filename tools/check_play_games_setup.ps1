param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$SkipRemoteHealth
)

$ErrorActionPreference = "Stop"

$configPath = Join-Path $ProjectRoot "data\config\auth_backend.json"
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Config non trovata: $configPath"
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$baseUrl = [string]$config.base_url
$issues = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Issue([string]$message) {
    $issues.Add($message) | Out-Null
}

function Add-Warning([string]$message) {
    $warnings.Add($message) | Out-Null
}

if (-not [bool]$config.play_games_enabled) {
    Add-Issue "play_games_enabled e disattivato in auth_backend.json"
}

if ([string]::IsNullOrWhiteSpace([string]$config.play_games_server_client_id)) {
    Add-Issue "play_games_server_client_id e vuoto in auth_backend.json"
}

if ([string]::IsNullOrWhiteSpace([string]$config.play_games_android_game_id)) {
    Add-Issue "play_games_android_game_id e vuoto in auth_backend.json"
}

if ([string]::IsNullOrWhiteSpace($baseUrl)) {
    Add-Issue "base_url e vuoto in auth_backend.json"
}

if (-not $SkipRemoteHealth -and -not [string]::IsNullOrWhiteSpace($baseUrl)) {
    try {
        $health = Invoke-RestMethod -Uri ($baseUrl.TrimEnd("/") + "/api/health") -TimeoutSec 20

        if (-not $health.ok) {
            Add-Issue "Il backend risponde ma ok=false su /api/health"
        }
        if (-not $health.storeReady) {
            Add-Issue "Il backend non ha storeReady=true"
        }
        if (-not $health.playGamesConfigured) {
            Add-Issue "Il backend non ha playGamesConfigured=true"
        }
        if ([string]$health.storageMode -ne "postgres") {
            Add-Warning "storageMode non e postgres: $($health.storageMode)"
        }
    } catch {
        Add-Issue "Impossibile raggiungere il backend /api/health: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "Play Games setup check" -ForegroundColor Cyan
Write-Host "ProjectRoot: $ProjectRoot"
Write-Host "Backend URL: $baseUrl"
Write-Host ""

if ($warnings.Count -gt 0) {
    Write-Host "Avvisi:" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "- $warning" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($issues.Count -eq 0) {
    Write-Host "Esito: configurazione Play Giochi pronta." -ForegroundColor Green
    exit 0
}

Write-Host "Problemi da risolvere:" -ForegroundColor Red
foreach ($issue in $issues) {
    Write-Host "- $issue" -ForegroundColor Red
}
Write-Host ""
Write-Host "Esito: configurazione incompleta." -ForegroundColor Red
exit 1
