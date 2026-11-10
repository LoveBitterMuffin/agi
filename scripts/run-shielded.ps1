# run-shielded.ps1 - Terminal Output Shielding & Scratch-to-Disk Runner
param(
    [Parameter(Mandatory=$true)]
    [string]$CommandLine,

    [string]$LogName = "exec",
    [int]$TailLines = 15
)

$ErrorActionPreference = "Continue"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$cwd = (Get-Location).ProviderPath
$gitTop = (git -C $cwd rev-parse --show-toplevel 2>$null)
$homeNorm = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
$cwdNorm = [System.IO.Path]::GetFullPath($cwd).TrimEnd('\', '/')
$repoRoot = if ($gitTop -and ([System.IO.Path]::GetFullPath($gitTop).TrimEnd('\', '/') -ne $homeNorm -or $cwdNorm -eq $homeNorm)) { $gitTop } else { $cwd }

$scratchLogsDir = Join-Path $repoRoot "scratch\logs"
if (-not (Test-Path $scratchLogsDir)) {
    New-Item -ItemType Directory -Path $scratchLogsDir -Force | Out-Null
}

$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$cleanLogName = ($LogName -replace '[^a-zA-Z0-9_\-]', '_')
$logFile = Join-Path $scratchLogsDir "${timestamp}_${cleanLogName}.log"

$sw = [System.Diagnostics.Stopwatch]::StartNew()

# Execute command via ProcessStartInfo (avoids cmd /c quote stripping with spaces in paths/commands)
$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = if ($env:ComSpec) { $env:ComSpec } else { "cmd.exe" }
$psi.Arguments = "/d /s /c `"$CommandLine`""
$psi.WorkingDirectory = (Get-Location).Path
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true

$proc = [System.Diagnostics.Process]::Start($psi)
$outTask = $proc.StandardOutput.ReadToEndAsync()
$errTask = $proc.StandardError.ReadToEndAsync()
$proc.WaitForExit()
$exitCode = $proc.ExitCode
$sw.Stop()
$elapsedSec = [Math]::Round($sw.Elapsed.TotalSeconds, 2)

$parts = @()
if ($outTask.Result) { $parts += $outTask.Result.TrimEnd("`r", "`n") }
if ($errTask.Result) { $parts += $errTask.Result.TrimEnd("`r", "`n") }
$combined = $parts -join "`n"
[System.IO.File]::WriteAllText($logFile, $combined, $utf8NoBom)

$logLines = @()
if (Test-Path $logFile) {
    $logLines = @(Get-Content $logFile -Encoding UTF8 -ErrorAction SilentlyContinue)
}
$totalLines = $logLines.Count
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
