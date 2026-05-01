param(
  [int]$Port = 4311,
  [switch]$OpenBrowser
)

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$controlCenterDir = Join-Path $projectRoot "control-center"

if (-not (Test-Path -LiteralPath $controlCenterDir)) {
  throw "Control Center non trovato in $controlCenterDir"
}

$url = "http://127.0.0.1:$Port"
Write-Host "Cell Defence Control Center in avvio su $url" -ForegroundColor Cyan
Write-Host "Premi Ctrl+C per arrestare il server." -ForegroundColor DarkGray

if ($OpenBrowser) {
  Start-Process $url
}

Set-Location $controlCenterDir
node server.mjs --port $Port
