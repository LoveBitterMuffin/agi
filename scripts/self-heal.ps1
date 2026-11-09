# self-heal.ps1 - Autonomous Memory & Workspace Repair Engine
param(
    [switch]$RepairMemory,
    [switch]$RepairPointers,
    [switch]$CleanLogs,
    [switch]$All
)

$ErrorActionPreference = "Stop"
$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  AntiGravity Autonomous Self-Healing     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$repairedCount = 0
$doAll = $All -or (-not ($RepairMemory -or $RepairPointers -or $CleanLogs))

# 1. Synchronize Chapter SemVer to Index.md
if ($doAll -or $RepairMemory) {
    $indexPath = Join-Path $repoRoot "memory\Index.md"
    $chaptersDir = Join-Path $repoRoot "memory\wiki\chapters"
    if ((Test-Path $indexPath) -and (Test-Path $chaptersDir)) {
        $indexContent = Get-Content $indexPath -Raw
        $chapters = Get-ChildItem -Path $chaptersDir -Filter "*.md"
        foreach ($ch in $chapters) {
            $chContent = Get-Content $ch.FullName -Raw
            if ($chContent -match '(?ms)^---\s*\r?\n.*?chapter_id:\s*(CH-[0-9]+).*?version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
                $chId = $matches[1]
                $actualVer = $matches[2]
                $pattern = '(\|\s*' + [regex]::Escape($chId) + '\s*\|[^\|]+\|[^\|]+\|\s*`?)([0-9]+\.[0-9]+\.[0-9]+)(`?\s*\|)'
                if ($indexContent -match $pattern) {
                    $matchedVer = $matches[2]
                    if ($matchedVer -ne $actualVer) {
                        $indexContent = [regex]::Replace($indexContent, $pattern, "`${1}$actualVer`${3}")
                        Write-Host "[HEAL] Updated $chId in Index.md -> $actualVer (was $matchedVer)" -ForegroundColor Green
                        $repairedCount++
                    }
                }
            }
        }
        Set-Content -Path $indexPath -Value $indexContent -NoNewline
    }
}

# 2. Repair Out-of-Bound Lossless Pointers in Chapters
if ($doAll -or $RepairPointers) {
    $vaultDir = Join-Path $repoRoot "memory\raw\vault"
    $chaptersDir = Join-Path $repoRoot "memory\wiki\chapters"
    if ((Test-Path $vaultDir) -and (Test-Path $chaptersDir)) {
        $chapters = Get-ChildItem -Path $chaptersDir -Filter "*.md"
        foreach ($ch in $chapters) {
            $chContent = Get-Content $ch.FullName -Raw
            $modified = $false
            $pointerPattern = '(RAW-(?:SPEC-)?[0-9]{4}-[0-9]{3}_[a-zA-Z0-9_\-\.]+?\.md).*?lines\s+([0-9]+)-([0-9]+)'
            $matches = [regex]::Matches($chContent, $pointerPattern)
            foreach ($m in $matches) {
                $targetRaw = $m.Groups[1].Value
                $startL = [int]$m.Groups[2].Value
                $endL = [int]$m.Groups[3].Value
                $rawPath = Join-Path $vaultDir $targetRaw
                if (Test-Path $rawPath) {
                    $totalLines = @(Get-Content $rawPath).Count
                    if ($endL -gt $totalLines) {
                        $newEndL = $totalLines
                        $newStartL = [Math]::Min($startL, $newEndL)
                        $oldSub = $m.Value
                        $newSub = $oldSub -replace "lines\s+[0-9]+-[0-9]+", "lines $newStartL-$newEndL"
                        $chContent = $chContent.Replace($oldSub, $newSub)
                        Write-Host "[HEAL] Clamped pointer in $($ch.Name) -> $targetRaw lines $newStartL-$newEndL" -ForegroundColor Yellow
                        $modified = $true
                        $repairedCount++
                    }
                }
            }
            if ($modified) {
                Set-Content -Path $ch.FullName -Value $chContent -NoNewline
            }
        }
    }
}

# 3. Clean Stale Scratch Logs Older than 48h
if ($doAll -or $CleanLogs) {
    $logsDir = Join-Path $repoRoot "scratch\logs"
    if (Test-Path $logsDir) {
        $staleTime = (Get-Date).AddDays(-2)
        $staleLogs = Get-ChildItem -Path $logsDir -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $staleTime }
        foreach ($log in $staleLogs) {
            Remove-Item $log.FullName -Force -ErrorAction SilentlyContinue
            $repairedCount++
        }
        if ($staleLogs.Count -gt 0) {
            Write-Host "[HEAL] Purged $($staleLogs.Count) stale logs from scratch\logs\" -ForegroundColor DarkGray
        }
    }
}

Write-Host "Self-Healing complete: $repairedCount item(s) repaired or normalized." -ForegroundColor Green
exit 0
