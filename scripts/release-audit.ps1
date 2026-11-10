# release-audit.ps1 - Git Diff & Docs-as-Code Release Verification
param(
    [string]$RootDir = "."
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$driftFailures = 0

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  AntiGravity Release Audit & Diff Check " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Check Git Status only when RootDir belongs to a project Git repo (never escape to $HOME/.git)
$resolvedRoot = [System.IO.Path]::GetFullPath((Resolve-Path $RootDir).Path).TrimEnd('\', '/')
$homeNorm = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$gitTop = (git -C $resolvedRoot rev-parse --show-toplevel 2>$null)
$isProjectGit = [bool]($gitTop -and ([System.IO.Path]::GetFullPath($gitTop).TrimEnd('\', '/') -ne $homeNorm -or $resolvedRoot -eq $homeNorm))
$statusOutput = if ($isProjectGit) { @(git -C $resolvedRoot -c core.quotepath=false status --porcelain 2>$null) } else { @() }
$ErrorActionPreference = $prevEap

$allChangedFiles = @()
foreach ($entry in $statusOutput) {
    if ($entry -match '^[ MADRCU?!]{2}\s+(.+)$') {
        $p = $matches[1].Trim().Trim('"')
        if ($p -match ' -> (.+)$') { $p = $matches[1].Trim().Trim('"') }
        $allChangedFiles += $p.Replace("\", "/")
    }
}

if ($allChangedFiles.Count -eq 0) {
    Write-Host "[INFO] Working tree is clean. No uncommitted modifications." -ForegroundColor Green
} else {
    Write-Host "Modified / untracked files detected ($($allChangedFiles.Count) files):" -ForegroundColor Yellow
    $allChangedFiles | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    if ($allChangedFiles.Count -gt 10) { Write-Host "  ... and $($allChangedFiles.Count - 10) more" -ForegroundColor DarkGray }
}

# 2. Check if source root changed without paired memory/wiki/ updates
$srcPattern = '^(?:src|handwriting_system/src|app|lib)/'
$srcChanges = @($allChangedFiles | Where-Object { $_ -match $srcPattern })
$wikiChanges = @($allChangedFiles | Where-Object { $_ -match '^memory/' })

if ($srcChanges.Count -gt 0 -and $wikiChanges.Count -eq 0) {
    Write-Host "[FAIL] Code changes detected in source root without corresponding updates in memory/wiki/!" -ForegroundColor Red
    Write-Host "       Review impact on architecture chapters before releasing." -ForegroundColor Yellow
    $driftFailures++
} elseif ($srcChanges.Count -gt 0 -and $wikiChanges.Count -gt 0) {
    Write-Host "[PASS] Paired code and wiki documentation updates detected." -ForegroundColor Green
}

# 3. Run memory integrity check via PSScriptRoot and propagate exit code
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
