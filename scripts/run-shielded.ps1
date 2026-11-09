# run-shielded.ps1 - Terminal Output Shielding & Scratch-to-Disk Runner
param(
    [Parameter(Mandatory=$true)]
    [string]$CommandLine,

    [string]$LogName = "exec",
    [int]$TailLines = 15
)

$ErrorActionPreference = "Continue"

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

$scratchLogsDir = Join-Path $repoRoot "scratch\logs"
if (-not (Test-Path $scratchLogsDir)) {
    New-Item -ItemType Directory -Path $scratchLogsDir -Force | Out-Null
}

$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$cleanLogName = ($LogName -replace '[^a-zA-Z0-9_\-]', '_')
$logFile = Join-Path $scratchLogsDir "${timestamp}_${cleanLogName}.log"

$sw = [System.Diagnostics.Stopwatch]::StartNew()

# Execute Command with output redirection to disk
cmd /c "$CommandLine > `"$logFile`" 2>&1"
$exitCode = $LASTEXITCODE

$sw.Stop()
$elapsedSec = [Math]::Round($sw.Elapsed.TotalSeconds, 2)

$logLines = @()
if (Test-Path $logFile) {
    $logLines = Get-Content $logFile -ErrorAction SilentlyContinue
}
$totalLines = if ($logLines) { $logLines.Count } else { 0 }
$logSizeKb = if (Test-Path $logFile) { [Math]::Round((Get-Item $logFile).Length / 1KB, 1) } else { 0 }

# Format high-signal, token-shielded output
if ($exitCode -eq 0) {
    Write-Host "[SHIELDED PASS] Command succeeded in ${elapsedSec}s (Exit code: 0)" -ForegroundColor Green
    Write-Host "Command: $CommandLine" -ForegroundColor DarkGray
    Write-Host "Log: $logFile ($totalLines lines, ${logSizeKb} KB - shielded from LLM context)" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "[SHIELDED FAIL] Command failed with exit code $exitCode in ${elapsedSec}s" -ForegroundColor Red
    Write-Host "Command: $CommandLine" -ForegroundColor DarkYellow
    Write-Host "Full log: $logFile ($totalLines lines, ${logSizeKb} KB)" -ForegroundColor DarkGray
    Write-Host "--- Tail Output (Last $TailLines lines) ---" -ForegroundColor Yellow

    if ($totalLines -gt 0) {
        $startIdx = [Math]::Max(0, $totalLines - $TailLines)
        for ($i = $startIdx; $i -lt $totalLines; $i++) {
            Write-Host $logLines[$i] -ForegroundColor Red
        }
    } else {
        Write-Host "(No output generated)" -ForegroundColor DarkGray
    }
    Write-Host "-------------------------------------------" -ForegroundColor Yellow
    exit $exitCode
}
