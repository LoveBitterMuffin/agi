# release-audit.ps1 - Git Diff & Docs-as-Code Release Verification
param(
    [string]$RootDir = "."
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$driftFailures = 0

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  AntiGravity Release Audit & Diff Check " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Check Git Status
$statusOutput = cmd /c "git status --porcelain 2>nul"
$allChangedFiles = @()
if ($statusOutput) {
    if ($statusOutput -is [string]) { $statusOutput = @($statusOutput) }
    foreach ($entry in $statusOutput) {
        if ($entry -match '^\s*[MADRCU?!\s]{1,2}\s+(.*)$') {
            $allChangedFiles += $matches[1].Trim()
        }
    }
}

if ($allChangedFiles.Count -eq 0) {
    Write-Host "[INFO] Working tree is clean. No uncommitted modifications." -ForegroundColor Green
} else {
    Write-Host "Modified / untracked files detected ($($allChangedFiles.Count) files):" -ForegroundColor Yellow
    $allChangedFiles | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    if ($allChangedFiles.Count -gt 10) { Write-Host "  ... and $($allChangedFiles.Count - 10) more" -ForegroundColor DarkGray }
}

# 2. Check if src/ changed without memory/wiki/
$hasMemoryWiki = (Test-Path (Join-Path $RootDir "memory\wiki\chapters")) -and ((Get-ChildItem (Join-Path $RootDir "memory\wiki\chapters") -Filter "*.md" -ErrorAction SilentlyContinue).Count -gt 0)

$srcChanges = $allChangedFiles | Where-Object { $_ -match '^src/' }
$wikiChanges = $allChangedFiles | Where-Object { $_ -match '^memory/' }

if ($srcChanges -and -not $wikiChanges -and -not $hasMemoryWiki) {
    Write-Host "[FAIL] Code changes detected in src/ without corresponding updates in memory/wiki/!" -ForegroundColor Red
    Write-Host "       Review impact on architecture chapters before releasing." -ForegroundColor Yellow
    $driftFailures++
} elseif ($srcChanges -and ($wikiChanges -or $hasMemoryWiki)) {
    Write-Host "[PASS] Paired code and wiki documentation updates detected." -ForegroundColor Green
}

# 3. Run memory integrity check and propagate exit code
$auditMemScript = Join-Path $PSScriptRoot "audit-memory.ps1"
if (Test-Path $auditMemScript) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $auditMemScript -RootDir $RootDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] audit-memory.ps1 failed with exit code $LASTEXITCODE" -ForegroundColor Red
        $driftFailures++
    }
}

if ($driftFailures -gt 0) {
    Write-Host "[FAIL] Release audit failed with $driftFailures error(s)." -ForegroundColor Red
    exit 1
}

Write-Host "[PASS] Release audit completed successfully." -ForegroundColor Green
exit 0
